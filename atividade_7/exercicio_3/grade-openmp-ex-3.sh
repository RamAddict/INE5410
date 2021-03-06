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
function get-legit-dirs  {
  find . -mindepth 1 -maxdepth 1 -type d | grep -vE '^\./__MACOS' | grep -vE '^\./\.'
}
NDIRS=$(get-legit-dirs | wc -l)
test "$NDIRS" -lt 2 || \
  cleanup "Malformed archive! Expected exactly one directory, found $NDIRS" || exit 1
test  "$NDIRS" -eq  1 -o  "$(find . -mindepth 1 -maxdepth 1 -type f | wc -l)" -gt 0  || \
  cleanup "Empty archive!" || exit 1
if [ "$NDIRS" -eq 1 ]; then #only cd if there is a dir
  cd "$(get-legit-dirs)"
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
� sû[ �<�r�F�~]~E����]�eK�Y�mdR#�I�l
�"b܂�dˣ��ڇ�L�>lM��~l��� AJ�8Nm�Q�@t�>}�}�4ȘF�9��i���v���������ջ�t66z��6;�G��Nw��{@z�IٕD���p�{;ZwW���+N����.V�����m~���f�m\v���K�[[�����H��������ֹ��΍hZ:><�W:����x�_��G���~e�ЏF×��f��`p�|o��~�WB�!��+��L�����,z���)M�����HE��/��pVw���JRa3�c�<=d7ŀx�Cj�+Y�GK��h k<� ���'�c?�n��:$�]�'q��(���Y>q;"�K?1�f�Y�a��2�%�s$�I4!�lB�E�$}�	~R%1��a��f��l�x��L��{;&��.MlBJ��]��/���������������Ɯ�?z�����ȥ������@�c�VƟ�%��7�q��ٌ������.�#v$1؞C�;`
�b4J�s�|��BMÿ�בqA�I�ͩ�}D,&b!�'�q2�~����{0ߛ�3���Q��W�$�Ɇ]иa�^L��hU���^��~E�!�4S6�o��vee���.]ty�iLH�4�mx�R��h۩�,�
l,�4NB�y�`x����A����I��N�*'�'�͟��j�w�5���T9uwL*1a7ސPU�M��ލG	�e�nJ��E�gl���w{�~�4�������r�۲錝
>0�2�wY9��<ԆJ|x#�AR@vp#� �L���+v�Z�jw�A����L0���\5�X;ȋ�)�rm�s�����l��1�ʸ��B�� ��xBޖW����r���n�U���3pM����+"�	��Z$�����1o����{y��8��&� M+d��&j�m�ۭ��7�2���R�����qe����ؖ�a#mkN?���?��\��w7ͮ�������K\+�ĳ���{G�{�щ>���������zi�mp����3�"��(���9�U�0���  v�f����ٱQ�95�IM��S��m+nAo��
;eP�ᛸ����\8�EY��sX�����,���Ǎ���fA=
�'f�6 ��0����؜�h�1�x�}�A$�P-��zd4�d�x`q�T��|}�\C����L���1���×C�-P;��Ұ�u���H�ϑc��=�E���[��:�i���v��v�.S�Pv���r���~��p�JR�k����cU=}���s�q&�nNm��������hP���ZuӌmaD�O���M��`�w͕n����3�,���#f1�����p�Y�/�Y�%�j�K��u��ݮ���Y�X��wz[�s��^��u��Wn����mD�q��	ؘ϶Y�}�o�a�͠�k8��ĳat��5����Q�N��\���1�9MO�#��:�?e+��ľk��8ץ ��s|��F(�:X�F���H�Yq8<��_���RmM]�r�:iW�P�����!ö����熾���蓣Ӆ�Wp�Hf��v�RLD �t6q��x��,\$��룣E�ȣA�E|�,KG�-Ò-W�U)�P�=�M},�.�� `ߜ�Ltr�Ζ��&�妝�M>��!��=�ae�H�9�P/� j��t}ȅ9�j7 }bШa�����_U�N:�_�H����������I!�ʈ9T�U�oL��q��6{"�B]�p����@O�!9��؝�L���
�@�j�7��������xMx�g���X�IyQ�U��-�FXv��H�Y�P^��i��XF&��3	)EY楞J���2�0�O��	�Q�p;�P9���/K�Gِ*�'�&XX2�3�&��ln�v��U�.>��t��j���ރI�)2�-�g�9����L`#������8 %,��M��͚�G ��usT��
���`p�%CG:�#<� ��y�'߼��Q�S"��4U��*1d���ɼQ��r#�ȉ9#|�����o��1� o5(9Z�u�+8��qF��B. S�"lF��I�)ؼ�cd8ZLB���b�+(���&�8[��)\�?��÷^��%�2%���$� ��t��^�)�WX�5!�B�)�	1���hà1�\�Uc�Q��$�<V�/��zZ�J�x�P"�M1�*Vb��ZT�H�;2X��֬���U|���=��9��8���-(�-��K��W�Z�Z���*mK��s��L���#��ϖ�W��h<��	Q͌L&KU��G��r~ɉ#��g(.���DH��) ����R��]X���.P$����I������ZO �����5�'cY�P])O��'����f[����.|E�։Ʃn��u�*��7gEyʬi �t��l�*�.0��j6�ș"|����g�E���1�֐������/���H�_`%{p ��@��*��O@�8�t�7~}�Cw
"��t5\4^ŉ[���L}�1�ڞ��)�m�IDV�%i~����Y��ɿ�kV�������I���r�J;�ʏ(����_.��*C�c�~Y�g8�U~
��Ax(���?���#�D�j���vG0Y������J@���	��Ҕ��P�)W#��Z#�w�q��Z-|��{/���C���^�m��1���n�(�*�X,��3���7:��u��67607jv;u���l�S���	�uۏ�d������^����-�u67��f� �'m�=�u��x���F���G��o��z�n��M���G׸{�픟O�Yo�%z8��a��+�Fg��9N@ve�(�����t5`��i����V5����)c`���=yF��L�
=-.��Ⱥ7r ܁���C�����c��h����#�̐R�.��Tq�Y�r�3SDTv��0se B15v� �)��h+N�����,�7�f���;�&���M�,�t`T��=�� v����FHp U��(��9�k�|�O�yE�����H�X�4|��(�U���>��Ι2�l-C���TԪ���_��*�s�T���C�7�ĶK��m����l�C�X��q���&A}��Ye%"'K]�	Ml��E��T0mU0�Tv��b��f��:s%$2������a
���Ŏ��w����^�F �z����:�m�66g�7�_���Uxķ�(�~����'�E�Ɏ��qt�a��wB/<!��M�1�!�䋻̌�4<�-ݢ���/sk2��F���|t$��a{lE4����>\�.=����(�Y	B��5 ���8�a�HH���q��oÈ�}r��n�3!$r��{%>�"!�>��,]Dd�i���L��+�^d�\�����z���΍>�V�8��V�IK�x�*��_�e����+u,��Éَ*��]li즔	�A�zDc�K\�S �(���)NB8pt]�o��#xڰ$(ʪK�>��(B�҈)n�3��*ꗴ��[� �HD���� ��=��)˟�Y]�i��C��G�x�7<�_���[$�}�Wyʜ�s��<K����d4���^ۅ�&���d�.�V����.P	���V*�
��*��=�����YXK`�4``>�❻��d�~U���uiň�>%�Y�F>�ţ$J&���X�Ȫ��c\'iaAM��	V�%�R�E��  �
g�D�	�j��"H�EX+RL؝YO5��a�d�x��12o��@
k!����}�����j��]uӇ{=��*�����b!���P�r0�`�ư r����)�٬7;�˄�s��V9�>�0\����~U��k��)�Z����9EM�1���@v� j̟�ˍr��[�	]��|Y�Q��٢��@e5"��ѣ�<��n[��'�~���OF�����ɩ>%y@=���J �/�{����6�L�h_��1��:��s^�[�����y����@���`:����NonU*"�r���a�;�;	���y����u2��\���Y2��P��צ�@���q�Om̹���d�`/x���Pq襟���*ь��o8�d���{�by��c`gQM�`B8kS����VO��ڗɉo1ۺ���:;��'y�4j6�,�{�W..�1T=+�W�_^�{2��̭���'w꘴����e��D�ΌkM��\M\�*��y���J�|Ʊ��4|X����n8}�F��� ǬX�Næ��<4��QqV�
��4�^L���"X~yf���06��(�Ra�HٱJ�w�i�,}�&2p^0��-46R;i[\kS��E�(�|���
�jt!�Q�t�����IO)��\O��US�`�v�f����Z0�Q���O��`�Q2�M��$�����K=?"�z!V68�/	D�ԁ��R�s�O������d��O���&����[6�v��̘\.���k;�����}�o}fם���1��������2����/�7����%)�%�o��!�G��(,���(�>�^��_�����G��K��[Z!��Ko��W�k��;�m�d^�<�I٠��!v�(���k�� �;��ͫ5k��������L�L��܁���;�aq�5<�#���L&��1���q�d�����HȶV�!�W�W׻�F&E}WґH�8eVj��ذY���Ϸ����%M�����c�Į��� ���m������Y��Ư��%��G{/O�Q�'�]}:����c�����'}_?�>��!M}�~r=߁!����i��d�1���״oX�ѣ�Q~�R>4���C��~0xq8����������C\R���k����I�Kp�I,
�X �Hf�MrD��6 ��n>47��:�}�N��C�P��/�"�Ა���].φ�\��@	�N�������g�#nȋ���f�7[�ǆ!�)�k��c
�&�f?��y<S&�6C �?�� 怒4�Uv��v���4]�jD,wM�ƭ��㾖a]�I����~CH�3?4.��9����Xh���x�ի�s�_���v�V��[\e��Q��a�UU����(���4�K��N��
�FhA�6���8�i��P�%bʉe}f(2?/b���I�!GJ�����L��q͖'�6�u��cN��A>`;ս����:Fc���1��a���~��F%�Q;i���Xm�@��H�9ǁ�`r��"��,�6!%!�]���h��H�>�`q������+�U-5���c�Qgas�E-.0@0�[i�Q�N����h� ���e��ES
��w �#g����I�R����pkJne. ˝�o>8�>���>��S�~�ߑZd){�=2�@۶P�l�{�qap�
)4�QZ�c;,��Qh0���
�bo⢡��}U�M򧄩��	4� �x�A��^í�ѫN�Z�Vy��B[��HG�$𑌘2�L{-r���������;����K�,�{N"�����.N$�w�(#<l�R#%LPD>[��h���ճD�:��X\��"�pX����l.F#���[���6�7��<K-�U����μ7�v�𔿢��W�IE��ѧ�|�*�Y_h�}�'�u�bG�6��c�ִg֔���c�<{�5�B����P5^����p����8i�>x��L5���w.'S9\�O�.���/�E�}��J8�A��2Ў���]���i]�Jc�)�lU�3p�
~f�Q�l���6t����u��I�(/��O%T3P�e����n5B���5;b>����z�>��s��C��l�Ip�wrOI)b%P3N�=����̴�:b��y�v����\/��%R(G�Z���TB�����>&�\6� ��H�ϵR���\�;>��V4o&���0p�~?b`�.6`�<Mf��2�y-XO^<J���Z�c�s���F�e��k��"�[ �|{����[�C�q�1c�xOO4��f5�Ĥ�<4#��ǚ�bϐ��<;��s�MY��9�^2��nG�H��
�럆���?�����u�,�@ �@ �@ ���e�� x  