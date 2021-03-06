#!/bin/bash
# Usage: grade dir_or_archive [output]

# Ensure realpath 
realpath . &>/dev/null
HAD_REALPATH=$(test "$?" -eq 127 && echo no || echo yes)
if [ "$HAD_REALPATH" = "no" ]; then
  cat > /tmp/realpath-grade.c <<EOF
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char** argv) {
  char* path = argv[1];
  char result[8192];
  memset(result, 0, 8192);

  if (argc == 1) {
      printf("Usage: %s path\n", argv[0]);
      return 2;
  }
  
  if (realpath(path, result)) {
    printf("%s\n", result);
    return 0;
  } else {
    printf("%s\n", argv[1]);
    return 1;
  }
}
EOF
  cc -o /tmp/realpath-grade /tmp/realpath-grade.c
  function realpath () {
    /tmp/realpath-grade $@
  }
fi

INFILE=$1
if [ -z "$INFILE" ]; then
  CWD_KBS=$(du -d 0 . | cut -f 1)
  if [ -n "$CWD_KBS" -a "$CWD_KBS" -gt 20000 ]; then
    echo "Chamado sem argumentos."\
         "Supus que \".\" deve ser avaliado, mas esse diretório é muito grande!"\
         "Se realmente deseja avaliar \".\", execute $0 ."
    exit 1
  fi
fi
test -z "$INFILE" && INFILE="."
INFILE=$(realpath "$INFILE")
# grades.csv is optional
OUTPUT=""
test -z "$2" || OUTPUT=$(realpath "$2")
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
# Absolute path to this script
THEPACK="${DIR}/$(basename "${BASH_SOURCE[0]}")"
STARTDIR=$(pwd)

# Split basename and extension
BASE=$(basename "$INFILE")
EXT=""
if [ ! -d "$INFILE" ]; then
  BASE=$(echo $(basename "$INFILE") | sed -E 's/^(.*)(\.(c|zip|(tar\.)?(gz|bz2|xz)))$/\1/g')
  EXT=$(echo  $(basename "$INFILE") | sed -E 's/^(.*)(\.(c|zip|(tar\.)?(gz|bz2|xz)))$/\2/g')
fi

# Setup working dir
rm -fr "/tmp/$BASE-test" || true
mkdir "/tmp/$BASE-test" || ( echo "Could not mkdir /tmp/$BASE-test"; exit 1 )
UNPACK_ROOT="/tmp/$BASE-test"
cd "$UNPACK_ROOT"

function cleanup () {
  test -n "$1" && echo "$1"
  cd "$STARTDIR"
  rm -fr "/tmp/$BASE-test"
  test "$HAD_REALPATH" = "yes" || rm /tmp/realpath-grade* &>/dev/null
  return 1 # helps with precedence
}

# Avoid messing up with the running user's home directory
# Not entirely safe, running as another user is recommended
export HOME=.

# Check if file is a tar archive
ISTAR=no
if [ ! -d "$INFILE" ]; then
  ISTAR=$( (tar tf "$INFILE" &> /dev/null && echo yes) || echo no )
fi

# Unpack the submission (or copy the dir)
if [ -d "$INFILE" ]; then
  cp -r "$INFILE" . || cleanup || exit 1 
elif [ "$EXT" = ".c" ]; then
  echo "Corrigindo um único arquivo .c. O recomendado é corrigir uma pasta ou  arquivo .tar.{gz,bz2,xz}, zip, como enviado ao moodle"
  mkdir c-files || cleanup || exit 1
  cp "$INFILE" c-files/ ||  cleanup || exit 1
elif [ "$EXT" = ".zip" ]; then
  unzip "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".tar.gz" ]; then
  tar zxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".tar.bz2" ]; then
  tar jxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".tar.xz" ]; then
  tar Jxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".gz" -a "$ISTAR" = "yes" ]; then
  tar zxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".gz" -a "$ISTAR" = "no" ]; then
  gzip -cdk "$INFILE" > "$BASE" || cleanup || exit 1
elif [ "$EXT" = ".bz2" -a "$ISTAR" = "yes"  ]; then
  tar jxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".bz2" -a "$ISTAR" = "no" ]; then
  bzip2 -cdk "$INFILE" > "$BASE" || cleanup || exit 1
elif [ "$EXT" = ".xz" -a "$ISTAR" = "yes"  ]; then
  tar Jxf "$INFILE" || cleanup || exit 1
elif [ "$EXT" = ".xz" -a "$ISTAR" = "no" ]; then
  xz -cdk "$INFILE" > "$BASE" || cleanup || exit 1
else
  echo "Unknown extension $EXT"; cleanup; exit 1
fi

# There must be exactly one top-level dir inside the submission
# As a fallback, if there is no directory, will work directly on 
# tmp/$BASE-test, but in this case there must be files! 
NDIRS=$(find . -mindepth 1 -maxdepth 1 -type d | wc -l)
test "$NDIRS" -lt 2 || \
  cleanup "Malformed archive! Expected exactly one directory, found $NDIRS" || exit 1
test  "$NDIRS" -eq  1 -o  "$(find . -mindepth 1 -maxdepth 1 -type f | wc -l)" -gt 0  || \
  cleanup "Empty archive!" || exit 1
if [ "$NDIRS" -eq 1 ]; then #only cd if there is a dir
  cd "$(find . -mindepth 1 -maxdepth 1 -type d)"
fi

# Unpack the testbench
tail -n +$(($(grep -ahn  '^__TESTBENCH_MARKER__' "$THEPACK" | cut -f1 -d:) +1)) "$THEPACK" | tar zx
cd testbench || cleanup || exit 1

# Deploy additional binaries so that validate.sh can use them
test "$HAD_REALPATH" = "yes" || cp /tmp/realpath-grade "tools/realpath"
export PATH="$PATH:$(realpath "tools")"

# Run validate
(./validate.sh 2>&1 | tee validate.log) || cleanup || exit 1

# Write output file
if [ -n "$OUTPUT" ]; then
  #write grade
  echo "@@@###grade:" > result
  cat grade >> result || cleanup || exit 1
  #write feedback, falling back to validate.log
  echo "@@@###feedback:" >> result
  (test -f feedback && cat feedback >> result) || \
    (test -f validate.log && cat validate.log >> result) || \
    cleanup "No feedback file!" || exit 1
  #Copy result to output
  test ! -d "$OUTPUT" || cleanup "$OUTPUT is a directory!" || exit 1
  rm -f "$OUTPUT"
  cp result "$OUTPUT"
fi

echo -e "Grade for $BASE$EXT: $(cat grade)"

cleanup || true

exit 0

__TESTBENCH_MARKER__
� A[ �Y[S�Jγ~E#��䋌Ce'�j	P��nU`�A�*d��I�$�_N�é�}�W��홑dY�1�����,���랾��0���=�?�è���n�ks���_Sz�l�Z�O6M�kZ���G��� M(# <"������?�(���1/�C�����j���?������8��s����6^��� ̧?��//�/]�~Ivz��1��~���^ǰ�'��v���qqtr��clh���O{/��1�0}Ѝ��_�@�Rw�uݏ=O� \p}0*!� ��Y��i �G��oG!�x�x`'���^�\i����2��F� j�,�߮��;�,�ց�#�a0$n�F,�Y�V�qY)Va
x�B� 6������J�K�U�(��]-�\\i>������B�'7�&���z.�&4�t���U�C�i�#blA�c�/���'-��B���^����^��{��@e���xƽ�3`Ƨ�y!�^�a��}qG�8��󨾍񗓑?_L�R��W7Iʡ1�m��I�n�ѐ(/�(7c/���`�"����}��s�p��1I7ħ�b���42m�Gԏ�R�_������㋣�Q�XE�� ��������e����	Oy��=h��l���W�feLJo"MTހFq�����q=θfT*)�Z�ZM��Bx����խE �p BS�ψn��T-��)W�˦^H��J]����9�Bh�y�m��u�~��Ә4#�x�'%]�cp>��yc�bK���f�Zy�S̭)f�}�XC?��Df�n�zUO�󯳬� ;;3�
Ǥ0�u�.��_��<�&(?��l�p�lB^ѿd���"Q���e�~ԃ3�/5�w�����U��,Ս]LM�Bc&��n1u b`�!&9EAB�����p�,��0)��$W��C+DafV��Y�Ѩ��+Uv�
��-�����k��h-�`7������.����FC������o;P��:�,3+6�w%��|2�N(e܆�3�������)N�=��������j�����7�|����@Ή:Q#��;%@4m� }�Ǹ���'خ��K����!]LAKPIͲ=J|�N͜>y��Jk	���:�z,^�ŰU�&��ia�f���l%wRr6��綃ãng�>r���	�Wxly�#��<��j��2r��X�ca�Q@�256�j�8=����UjQH�鱬�_&��7d��!�_H���3��']�I���ŭ��ܱ������(��D��㛜��.��&��r���y9�q����D:3����4�Y����펈���7�g���������Vr����E@I�^".�vC\,M�|B���j�\>��FxE� �P"aߵ��y�߇�a@� W�����Ƴ5��CLm�?b��JV<��Å͂�x��E��AZ�֤�[��+LG�꼧�<{uO7�>V��>�txR�f.�"C���� θi��,*m�Q��(0��GL/���x���06�O=��Ȼ�gAS6�	�r�kF����[�5A�T'd�8ª������Dvޫ7�p��.�������.��hz��H��)��!|�גC@Z� m6�H�@����ݐrU�4p0�ױ�c2����y�&�q�2��_��0���E=oNj(��v��B8�7\cY(��8ٸ�C,�9K%�\�:&y��yq8���㲪��g��8�'�!�)rҔ;�#5��
���:�(�$��p�k��pHAipv����|f	ܣ ��Y�ZG��N�!�EY��G��$���lI/q9/6�@��Nj��Ŭ�F��'�c{�A�� ���K�WBzZ`�D�V�W�	���&���O����\���ƈ�%�'���1W���0�LC�ʤ"VI�Nn��Bv��$��������+XY�Ө�Jܪ6ܹ�ݩ8ܾ����;�E�u����)�n���d�B���_t�7k�i�@X���)�YǫSF�V�g����:���Q������jX�g�7	N3*���G���O���T�5�����~��u��om=��~�C�����T�*����|��η���;��q�u��Y}���o:++��&sJ������'J���,E�������ֵ	kk�Z�q�4(*��b�e]$u��B���i��?�I��Aq����dO�����!��������O�xvq\�w!���Ľé�_rT��ÿPt�|�pI�f�QY7��M��i:k���MV�=|�q&����'g��O��trH4��
��8��"Γ3b�ķ!;r޴�*Y%�����?*����)��sw> �+S�.��Ee�.j�Yz�*K���T�Ew�'��;�,�戧���9�ԟ�)R�H�"E�)R�H�"E�)R�H�"E�)R�H�"E�)R�H���� ��{ P  