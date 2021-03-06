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
� rû[ �<�r�ƒ~�W��K@�w��-�Jd����I�D�d�֢ `HB�-�H�|�1�}8u�j�N��~l�g� I9q��:F%1�ӷ����� ���>m>�î\��.���ݖ|��G������v�I�Q���ju���RzEA���<�,����-��z�����k�|��ov����W���?�5��o43�r4����v~�����#��r,̿����q��t�Z0-��Vۥ���h���)�F��M�C=^�V�J/����?�V�%4RwHy5n-����$ M�^7�ȲJc�'&1�����pVv��	,J=��(ã�:<?d/��x/|�]�ס%sL�9��5�RQ}����uM-�6u��Fh�Q_s�ؚ��&��n��(ðB^��1�3,/e��6!b<f}�~Z%!���ɪf�W&��?����H�r���6�d��&!%��*��_��@�nSB�/acK���9��O�l}���r��_zu��W�oGb+�ϝz�;R�L���<�ko� 0�	avD���(۳hy�O�!���fL�q��W�0I��݇ h�CV[�K�EĂ{�iY��Ĉ绞뇦� �w�=�7�9��p7�4���а��NH��(�	�^�_��ު2�!���S6�~�aeee��S:��:0S�6�;�8���Ѷ]i��X��i�������5�B��UE�a7ڕJLd��w��s^�Y� �d�Q���-!c�n6�CU7���(�<�ݕJ���l�����Q�]��|r�k��Qy����L�U�#=X��0�2P�Y�M���f�Y���l�d3��S^5˕� ���@B��f�e����Ҫ��A_L�hH)���\�-4�D&�e��`U��gB>y��c���ߗk�Q�+W���W��t(i͸"b�S��.�]��"��}\]@r/�xǰ��;@�
 Y�O����V�9��R&{�@Q*-���W��_k�ih��ד�����E���������$��w;[����q��cǠc���?>:�O�Q�l��?8x��V��
t���!J+��[D��Ahh��1ݓ�0���  v%f���阡Q�>��*IL��[�vM#n@��~T
;㠘�7�!هչp����F��� +��Y��X.$$�;�zP��Ƀ:���m@`�gG���h�>U�C�/rs�@$KQ��zJ=(2�A�`<�8E2�0���:��	ۇ\k���\��ѫ�L;�<�P��5�?��X�ρe�=�E���*[@�
�o� v��v�h6�\1�ntS�(�
���Y4fż����8�0PՒǩ	�@sFz?rT}jZ\~��~W��G��j��MU+��fb�8O���@Y%�����-��l��'Oe����GP�����p�Y�/��%4�s�K��m��î���Eh,^�������������+�t�nv����0��l��m�e^dۨ�;9tc5+�9&�ζ�Z8͍�41�dZ˅k��Ӥ�d0�ۛ��3���J�ڦ��3]��3�կ7�p@���2w<�]׈pD*��B������V]�*���Ј	�H�R�F������3zf�ہ��>=>�;z��$�(/���c��4GJ�a�A�!���y��=>���,��'��\�dqD�",�rU`\�P�E��ԧR~م���줪�)�v���5),7��iD�g�9�++G�͑]�:�P� ä�B.̙\��]��GSE�dT$䪐҆�H��5Cr��� ���Q�5R�%��BUn�g쬇E�Ş�
�P�#\n6��� �S]HN�q��{�Dy�C��������urgV��a�ƼB�3 H�p,;�</�*m�ޗ�,���HPX�P����@M��Tew��اu��z�I�*ʐ�p?o�'t^��I�vg�2��_�a@e-��lp�mB��'-���]��1ٰ
����I�u��2�D�BbxL����~�ū,�6�AL_lL����R�NҤ��۬��zpB���7W��]���8t$T��� ���������1b����<T�!�v�q���41��!��)��h��V��@�6����G�̺$�R�8'R`!��M��l��؊�)ؼ�c�p4��Iv��;VP���A-&q>?��SZ�$�7���r�H@2a���$� ��t*)�^�)�WX���B�)�	5d��hà1�ܔec�Mr�I�y��O@�ZR�J�x��"�]1�s*V�d���'�lÎ�i�5�*�q+w���9.Ǿ"9���9Ű�\8	���Aki�2>>�Ҷ���Ι�ٙ:�!�(l�x3G���A� ����da�
;��|�S�.9a��%�9�9��K�@��
*���U��kqP��O�����C�Ig�x.0��c �c�2��,1���ٕ�|:YF�t0^��F���uvN�+�A�u}�֝<�8�`zCqVpT���M�c�*�������n�Ѵ�@�&�%Ҵ0�tz�>b��P���O�������l41�OG/���?}� �@B�
��_��O8�l�?z{�Cw���t5\D��ĭ�Ҵ�.Y�^MǍ�����( kƂ4����}��Y��fZ��I���(�4B�x��X����b㟨�Q��_��ߪC��C�x�Y��Y�U��Ay����J������#�D�f����$��7�\�o)��9G��4�=:T�8֫������
�J���f�n��j��-�q��6��`�l�U|�C,������9[�������t���5:��n����x���:��5���~��[���[��6��[[�V����Ƴ�ޞv;x�~��n�����v��6��n?c�n��L	�V�[�=�v�ͦ����=\�?�0LؕX�S��	���T�i}^(u�0q��IRbor�U�dmp{��%���B�r��<T��ɵ��F���so�~H1 9��`�a~A�&�ގÈLR����LG�Wa,�O�;�i����0(�Q
 &���`#^m�i��?��g���4�w�g>�DS�8K��w��TӞ�Q��*��}�=�%�oj>��T!�B��7��$�5�kr�+���E��ʤ��\��V�[������|-C���Dղ�[�t�*XϑR�Jf���%��X�l�L��a�����{�!e��r�ϲ���X�Lib��ͫ�$�iɊ)�}.b.�*�י+!�����=�SPF-v,�_v�Wt�{�k,��:�]v��iu7��[�ַ�߯q�-<�}�1q����ޢ�d˴�0Xz�����C�'�ٽ��Yzdi>�|q�,����%�cX(Kr:N�H�7'Ӱh	a��*��Gݵf�x񾐪�TX@�t�Ҫ���W�*>\�/����<�v-��Јl'��x�6�5jĐ�Y�0��MlOlҀ�]r�K d�2��wfU�n\b~m�r�)�_J埭�ߣ�Q�|��)G����Z�!W|�U<$&pU����+0s�∸o\�sm���4�+�]ZOy���^~2�t*.
,,��Q���<Ւ ��
+�=���,ڼ��/ƛNDw���P�H�B�='�SeF�B������<dT{B՞��7_2,|����nwI��<�iz�I�,��xށ�$��bM��ę-��d屼O��vߕ�Í�����̦�6���@� ���4�\/����m�Ⳡ�ς6��4T�Ȏ%*�0ѭ��ς[�?=��_H��5Tv��*3X�3��D�� �*!,1'��	!�]��̊�U�(k6��� Y��+���eJr�\�A���c�i�V��?.�z�È�]�	�ʲf�5+b'|H�F�����/pwH�"3N��Z��9V�M���ζA��{���.�`��ϧ=?vz��~ �0u7r��x�k�X�RE��}�9��3�1�⊿tёX�P�N,�-ԲAQ�nsi;���Կ��8�}Bd~F�nw�A�R��oNM%[�M(�\�����u�����u_���5�*L�}|���QU��e���[2���EIk��=�E�r���e'g��V+U�����c �XQ������v6<=S���A<<~ob�S�a�2�dAI$�A`��f����u4�o���6������9�@�l<�3��$������bw&�)b��2��P0���Rv�2R��a���rkdj�^���<5��p���8-��!ꂸS˦�s�X��_����+���k7"k�M�A=h�W�f퐵�����d����G�! �x	B��u˭4;���T��5r�̰�+,����� ���@� qK�F��B�ま.�xp�Y�
�����e�.����t�1I���W�F�����ֺәsQ>ÿ��Kݳ���'hPs	�@�+4���4\~�zL�2�t� :opu�E��O���2?�2�����W���H�&��V3�3�t��_{8S�'�;$����^d��	�ݤ��#[i�Yx�Gm�%����E�a��L���Z*�3��`Z2R���e��ڒ��skW��OH�a2�)�ٰ=�N�x.�SeNH�bO��:��g�����M���\k&�&���������22���N��_}3����~1�̘�����L��������W����^+�Y�{&g��|��.U~���k��O������Z������ou�}���\��_�/����G&�%I�������B�JPn�֮(�~ߎNގz��C����"[Z!�M���3�[��-�da�?�x���A��C�@ M�����t������j�J ��uLӈ@���t�8mϴ����!�������T���	�K#�:C�F5&FDv��.�^�?]�1R-�uk%�,��l�/5��ڰY�ϑ��_a-�}X*��� ���Z�]��?e �֗��%��vf��������������^]�������=�?O��ΏO��dxv��z��ߞ�{�%x�zv=G���w�#�	�[d�>4�㛷���9|�8K�����i���_�g=��~��mD���uHЮ��\��<
��K�_s��_"�\��C�@? �L��>�C��KD'$x�)�#C��Ѕ��`;T4	e�:0��Dg ϻ�l���1����j�M� Q 쫃�:�ͣ��X�f2PГ4!ǳ���aL�[2,�@&
8�/o@f��������k 撱CW v��N���4lͨ,���MO����f\k�N���n]h��?�'ԁ=��&Lɉ��7#��7o���%��L�h�V#�O��9xF=t�q4�k��B��K�%nag�U��o@��A��$
��_�K3W鍅Zn(
?�5'`�$�ZC���.���
��N���[�<�ic�n�>5C�E\j�=V�5<ݯa4ƹc_�ق5l��_�v@O��"�p�i�5\�_�
�MͲ`�]��A4\�ł���]�삂�h��H2}��,7-X/�.�V$d�Rj���m��T�(��y(&��-���Q����� �@YZU�)l���}�P�9<:�pEJ�;�������`�3��'���jcg��k����w�EJ��8�@ێ���	�{�D��JY(��Ah�%P�����4���h(0����s5�mA�,����`C$��6P0=B�B�[@�ʪ�}���c=�֫�Xߛէ)��N����ξy3Z�5wmh>�2�"N4�ɠ�%G�H����w���6�m�vq�0\H;*(�}I3�D�9��&m�4�䳳�{��<��,n��^���U������'ë�Ij�Qf8���Z�v�9�^6���n�E|~�,�q\�?RO1�{ő/m�����r�|S��w\�Yt'��v�kmqk���Hu4'W�Ս�/1���8~��`��"5\�ƙ��PV7�
�7D���]I����BC(B���4��J�C����9��Cٸ��%F5'��+��5?c�D�@R��ȷ��޹W�����D�(�5�����n�!�wﲘ��1{�ҍ��ڭ6t��G R�
l�����7���Ь��ހ�6K���֙����"�~��^e�}d�8"҂ҜC����ѯ��c����9u�i{W�T-����G�AV+��&�E�0�O�4b��!6��<M�.9fHd'l/�r3Ɗݚ7��c�h[��UNQ��Eb�ĺ�%����ˏ_��S����M���"�]����ԋ��$�Ut�ŉ#'�m����V��f9�����ؑ5���8�?���gQ�㹙�B&��.�
�B�P(
�B�P(
�B�P(^�+�U x  