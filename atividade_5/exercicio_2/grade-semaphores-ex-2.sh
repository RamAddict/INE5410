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
� M�[ �=�V�H���O��X�6��fpf8C �N�Mru���ؒW�!��칿�}��ح��[j}{�:'������#F��\�~�͞<�76�o��FG�+����Ϟw�m>[��������Ʒ#)yfa��|��G7̇+���>Q,�����7т�忾��(�y���!m_;nt}������76��ߑ�������忸�z�z��NxY{u���ԭ���v���j{ǯ�ζ����������g����O�{�n/m�P}H�#�%YZ'��Nb��!�Z�f�qm��%�G�!�Yb8��5B�1�S��z��Ӑ��+�Cvb��<�·���h��F `�.�����'�W~~���ȝP��4p��O&��لL�����i�ie�gH.%�F6!����q���$�������-��ȖwH�r���.�ɭ�\Bj��S��7��=���C�J�?8�����\��������~�>~}�f@j��V����?��pu�>5�^�a�z��=��"н1��@�*�|4#J����C&���_��й�[d�é�}D,:b_�Ƒ���i�O� r}�{k�yv����(��WͼkvA����"�E�a�/ �S��#�p{�q�i�/��������ť�V���S~ ĴG�K��-�zI�!Zۮ8�+�1��hxl����Y��pe�ѐ�+]˒�dIx��[�[ep	 �'��@]I�V��m	e!n:i9�Pֹ���Ղ	R�ҁ�o��mwk�7�N�;�3�/�X&�g	��6Xk���ҠֲP�*���AR�w��� T5᳧��֭� W��Y����d��#���jh�ʁ_�ŨH	���|$�P��1,�_�F�V9��=�2\/�w�'O�F��-�z��[|�֗~���Q��LE�2�!�|2�'0�) b��a�H>˵�1,5�_���v�|��{�鬮^|o�Ɏf(j�r���x��ݡ�A;.{zy/}���|�,��w;�gi���y���,�#oHGĶ��{x��{v|b��O�~���b�b۵E�va��C�]o0����[�����R�A7�@�+V3;:�]ύ`�� .��Ibճz�+���C��Oc�4����}�����6����9�`�	��c��$��Ј�K�z�"� ���@oF��ډ�6*c��y�{�%KP�6�z`$v
���l�j3Wz��G[�'~����^�(���Ϟw3��q��a�t��n��0�A������Y�l8v�3e�Lw�� ��^����n��7���}�Rt]��}a���L���]�X'�F$�����f��å]�v�[�l��]�Cˑ��ȟROwF��s&��Q9���p�ٓ)�g46вC�������.� =+�Z��j�O��"F,1�q��j=[cg5L�@e�},�E�6��fm����mَ��5#�X���l+���Qk�I[Y6��U_� ㆀFS�����S�چEN�Kɏ� +���<<&	��HXv���J��:�cN�R���;_�%xn�
���zY(m� �A���Qw���D��%��e���-��bl=� ��-�O7��-��`O_�Jyw�?r��c?���ޭ
�9z}x��;>9<���8���6��=v�"�P&"J,jaAq�`M�0t?S0nPn�BB�4-qC����� iwߓ�m��;�{e�J�֍5�L4Y�t��*��P	�XdG��'�s�J��w�z�G �ˀ���[ |e���(��=Ql� Ld(u���,�D{����_IK�OB��ްmUs�C���|k�yPg���2\x�Ս#�.c���c�ڶf%�� ��X�a��0��2O�G�[&Ơ�z]�U�O	_��K7�.��xI�qs��3�9N�ez)�@��څx<?��V��Z7�G��|�}9��S?�o9k�B*��
��x�'II�-���}���V���������������^� V�d2�(ld���Y@�꺳�B6�{X����/ J��"�<��l	���w�7e ����6I$x�<tG# �m�jo�lg,���T���tB��1>���m��U��hj�B��v��U�ؘ��߽p��Ǵ�OVY��G��}ss=��_�|\�?�c���t���P���t�v�cd1�pJ6�k�ʳ�C�M#\�G�~��;u�GFN@m�bM����� ߦcw ��%,���>�~ q���1s�*���H��� �N0z�����p:���d��vm\3����z��#++̢@!�����n��%Tȇ������a��[�`��n����3(V�
�M�Fy(�@�G$�~�L�.�U]�c%�xPOAqSKTL[� ˨t�Y�6E�6ڼ`���<�du�:!���11�N�Y�B�5q�GE揮ȷB��К��SJc���
)T��o�c�g�z3ZƖ9����@䌊��A��scD1�v�顶��$�������6M���b�28��Nu��}\g����%.�N>�O%�_���F&�{���=ēh٫3����W�B��d�Týc����T).RE3�P�Kա�<����<��N8�a��f���&��x�o��Zfx����R|u��m-52 V�ݾ����k���W�oc��f���t۶_���7ǯ�Gk���د�O��{���듽��Z���_���G��� �d�/���}��-������߃<���q����{��)��kkݵ���n<��yL�?��~9����n�����3"j�H���9��BX!��wh���aX��8��UI��WAp���T�rF4N���M�^�D�j9`Rv��٤m�щ3��9̶�d&;�i4�c�id;ZB{pnGV�П\4W[D~D��*. �ǈ�y�~�hX @��~y}����{+�^΢��v��r�:�ٱ��ɩ�JL��4�U�:4��TAD6P�!� aD��pS����� R9����X���i��)=y5�>���a/." 2,ç��)
�X�����
��d+v�gs�4}�P���a^�*v�1��������,����7773������ǔe{���rA�i���ݒC�c��lp�yɡZ��9;��J�S,�Bar+\�?v����fA�^ѤS`���B��U=��pGQ�{
��UC�g���``�cN��GJ�,.�h*�(�T���I��v��r��҉�7���e0�Y�#ĂE��a�NA.��@?�Q.$RV"r�5k���i��ү�|}�c����W�Dw�Md܍T7M�eְV�DQ���7L�y>z�;��\��o�^���h��R��N�ɀ4��	�ܝh���&n<��4�t:l%�S(���I��
�|@��� �-��9Y��T�T�Q���)��e��xTڋ�2'��~�W
�40��ؿ<{sp�����O�h��c���^�H�U$���H9��d�0~��D���w"�o�O��~��m�q,��e24�ɜ+QN��a�QH�Y�<�@�=t���E������_�;©�{�ob4{���~����g'�������&/H��S�8e��%9{4�Z�Ϩ�
v�K#OB���Y�d�?_��=��뿆>�{�'��)"-nO���,+��
���z`|�3�o�>���/01ApN?	�8�O_�|^�4W�� ������1�����}I�P�K���펁��~��dq��]�}ǧH�o�	��N�z����G�]niT���x����l��cĲ)<���Iz3m���������a�X�d^��f�ٖ����oW��-���6�A"����j���R��C��e�"F�g"c�x�'�r��=h�+2�`�3�T�1�J�a��:^H�|��{}rz����ii%*or
��5���m�]o�Ѷc���,�<��.O�vA%�\)f
Ǫ�%��ʓZ��䫍����'����X����kJ<�_�!�Kʭ��w��3�Ly ��]=��$��m�R^��p��u�G��.����@]-�^N���Y���405Q\���1Ee��M�^�XH$�!2�Z�aK�|�`�ź�����4D|b��Xn&hK����7*��N�	�=���7N�y
q�GT�5/W�#d�g^�P�('�4,�x��L�0	sX�2�݂V�Q�$�Hy-�&V�A�3;/N����勇/�ը#:!O�@����ݹ�9�_҇co���W��*�S�TȰ~�[)��٥l���̆��k^ƶge�E@I0�*c(�� N&S��y2f����6.�u,�A��c�b�x�Y���_��� -��2Hn��]�w3���[)�uz!������EU�|f�u߂(�q��Q�2�6�-���0B�u$�0]ߋO|S!$nt
�G��v'�>�e)�`j;<�3새|Y��=�Z�_�E�9�qqsUls�Po�����%>����:s2~Κ},�Q�s�l����$'rI7������Ás���B��j!D���� ?7Fy�Or�S�j�6\�P\��R"�ʨ�EG�"��5�բPH�zcʜ�gX���Q�d�I�+Hy��)[�g͹�� ޅH05x��iA��v������i�ǽ�Ҭ���N��C��*�b)&�\��x�S1Ş�-�\�S-�%W�Ä\L2)	𤙘K�X�{S+ɠQ�k���3$�RZ.s"="`�ɹ�1�̹_�i���i�A�g]l-+�.3�2���z�n��Ʉs�0{^_E��|�D�"aK�ah	���zk`� >���ط�fc���1K�ɭ��J�v|0`�1�hn�b�o]�m����}e��lU[�]%[X����ǂ<����&��Ĳ�o�4�����������}}x�,��7{��y����d��b}�n��wR��x��:C3o�J/��خ.�s�_ЦDY
�n��m�����8*8O�L�p����3r+����L-B'b98p#�t-���P�ot(2��ʡm	�PzU�&��r��,�*�4������r�a��A5�9�MU�Ä]^&mJ�lNV��Q�R�-G��a����-E	�A%�F��K�ۖ���07��e����!�+���_A`�E�uI8WN T���*����?et@�y�H a�LK��Ț80�
+�K�����)J(����S����L�.�ׁ����n��Ioy��F��bu/�r^�Hq'��ʼ�~&�J�����TU��~������(�RLo#I����T9��)���U9�I��ۈ�Yxp2��f�F+���F?���A.	�7 �%���-�a�D��͎^�F�`CǑ}�!�$�|�?v�U~�b�I**��*��$h5�1D������۟�s��&��9���e&�\]'$���oY 1[���x$��Jr�'��E�<�j���'����<��N��_|C�[��Ŝ�ũ�H�fF�V���챊����	�:?�|�J�����$�\�^V�d�%=����?�����s�>�W,��_Zr2r���Hz�X��N$+����P�D���D����P]AdK+G�'m�V�#�z�R��a�6��5��×-�:|ēzU��}U�̞���\6��ޗ�5YJg��`C�&�y��T���9�����b�"�<��M��B��6�����>��zdu����{�`E�'\�� ٫Gs�8i|g�rT#���D��?�݇Hk�	�p?��@��whz;�!�)"�!R�E�$�q����g�=:fېl����\���7w��\/���^`���/�������K��� c4k?��-��
IG���;M��͛*H�jZ�.��38�r�)ު�(�7����������G���:��?����?<�c|��!8����7@i��Xޝ~�:A?���t�ab�b�r�L4�,�u2�Դ킃b%���J�b)��xfA�1��:&���֤��lJY>�&�_���Gy�π/3+3��v�~�mj�.t���Rqn�=87�L]m�&~d{Ǝ;�g����V�K}��6���"�g�*�_� o��x[�@C�ʺą}7t+3lL���b��E�պ�{��:�߿�'}����������������C<�/n2���</dR��R�	��AT��Zs>c:�t�����Xw �bY��@��`��X��DY�,Hp">�n���)t�%��~���I��U�.�[|�k؏����x���49�r��f�Z[�d429�inQA*b��w%\�.q��?�Cs��<+�̆�[��S(N�Os���[m���g�=' ��������ڻGJ <�g�P��Mb��[	h�#��BQ58��ۊv���QX�~_����<�����r��%5;zBّRQ��̸�ćć��"��^XW�xWJ�nA�x�j�{Ƕܶq}6�b-�R@R��))Q�Kܑ-U���d�
XR�qapab��?e��>y��W�X�9�,@PdŞ�8c�$�{���sۻ*���֪���h$���ݲ7Ԑ���Y��r(���&
sňlICޯ��P޼��n�}%V��f#S�^�Ih]+��Z�?�s_��?���$��@��������S�}�oΩ���;í�|��#M�Yt���8���͊C��΅<x�����CA����>�~:���e��-4$���۱�ʈ�ղ�xN��Ƌ� ����%W�ЉS���\đ��)���~au���ݡ�wu�����|��LD)C�R�MdX)w�`A��h��띂��q_� e<���U E#QҜ��8��m�0N��[T(�^qq��*�(O��O9��`��,e�m}�3H��B�-I��Ӆ�'�PZyWҩ���e�Q*�����I���|���sվ��5B�@z|��t�y��b�d�����g%�u��N�y܍����u��3���렉<w����1�I�uS��kz��i��Oq���
颶yd4r���\���[e�jc�n��;���z���Y�V����#�j����7>���͘�\��@�=h"���H�D�@�9[
��cw�� �1�ť����gfKt�p-�ae�Ueht������F}6Y�Q�����g0��"�x�/ٶ\BJ���ӒC��֐�Qm�����z�[�y�t��HJ��)N�˥�"]����
�lC�������ކ䮍7P6XH�|�:[��7�/>8�l��F�]��W??���5N�eq���9`8�T���siQ;�aa��F&x�S��.|��=-X:�G�r�m��HD�.[^�x&;�{����C���Z+�̵��>�#�^Xꊈ'~�:yS4[ٱn�{JzN!�\K��/�����5�i]~��j�l�%��l���74�w�JRT�rKxt%z\�^,:�@�
��)����P��Ҟ�<��FB��
(�����b�Îcp�X�>U�c'�j9���;U��D�$�g�j�k
��9�S���W"��C�^.Iڪk.v�ܨ2��t'��]ͽ�m���$=���:� ���C"R&�w����|I�n(��Z��ߊ�9�%c��vbB5yZ��"i���r��e�O�o�L9��� �mi�^��K������g�z�2)���yT������Q0Bٔ���k�꧶�tȌF.	i���)�DF؋��CS%=�ͽ�]�m�2q�#HAR�p��P�T�;��#U�92�Na9��2^���t��O�W��&f�.ӯoH��v�k$�쟠rl�aO!���I$��H�2�����O%+�蘯t� <�'�ٚ�
N�,[�V(�/E v��.}2`���Ν�������v{��G���i���0o�x�{)�Eü��V��G_�6���.j�`+�jp�9j�2-Π���=G��~��|��3$b�H�����=��\�޴9��[aBE>�����UH+UC�+�UX�AAQ�7��V���Ѝ���ٿ l��T7���OY���0I�Od�͸�ӛ��ΧU���"�y�.!�H�:�ٻ���F���i�ɪ��fx�%��⼬�e4Dzx������^[+�a����&�}wS7٪�0-E)���Ca��#�U�)F��T���\�Иk���!�be�(�v�^������V�+e�(�d� ���i3���.k�;H�U����Xő�Q]���S��d��`�ɓ�$Y8�@]��K���eT�݅��6����q�t][�B��֋���/OC)ʭ�|2{=��@�R�ú̑x���+&��J��V��\'PЃ��&��u?���ȺaQ�Mg�UxV��>���/�md�52RC9>�v��*J*CW�܎z��p��2������SB��{�_����/cY�o������v��G������Nw�f��}�g��Q��7bt�}jV�ZG�Ύ���������e2������>8ݵ�[�A�b��s\�tH2!.o"8�r?e<�!��q�B�� 3�0 �'�tء/a�1��b���1s�� 0N��o���#��Pp�)Gp�s�詊C�$W YRXIG�C�	A�����tč݈��	N��co�+>q�Й�\Fe��)�`��%�:�*�q��ZZ���2�&�^�q��ک�����D֛p\�����L=����"��=�Hhp�Mr�Z��[���O�܇?���!�����o8g�l2�GhF>�,�6M�Y��7�h��z��G�N���;?"�'�p\�@�ja��� c��V-+V�<YJ�d\r�&	LR���"+x��p���і�F����^>�^'4B����d�	9���Aky�:��/�C�Ȅgi~�f�6P-˸��@��+�n額��g�+K*�&���:szR���Hp�A1����|@��ù8���aBt���n�iGT���}N��@=��%��s�U�r��9z��!c�Be`�(�p�	�P�D�,Nr�w(��ń��+��z'��-|\e���w@��?>��v`{�O{Q]e�Յ2��O \���:�n�<pH1�O��T��o��gC���d؟�1���x������O,h�!6%�Z%D(Cx@(t0A�@pb���kN�BVF�ʢ�`C���qP餐�fA��B�ֿ��BY�	���$F22A�]����-InF���ٯH0����h	km*yx1�G�)��8-	O��qF�b��g�X2�[l�[Z���4�v�� $@JzWʂ�n�d}\��u#�2{dZ��;-���ܽ��Њ�E�_����!�F�kq��N�����oY�(����*�W��ۓ�cRS�l�d�vq�V��=>�%���X"�<I��z急q�oȽ�J�:`�;�� �i�I�WL�Nd�Pf�B��e�:]�dȬ_	�:<A^����<v�}iv�$����wA���%�-��]cԀ"�^P�w�p֊B��ޡ|;�|tA�=�gJ����a���2��N8��#�9�EUZ7��&Qv�����{0��4��q��eI�J���F�Oo��e�KvS�U�uU�j�� ��"�ډ���w F�`�U#*��yCv[\(�&����S�D�]4�^�"��0�'=;�JȬ�<%���w^�W>��K�VuP�˕�~k�,yו����g�4��A^����_�������.����G`n��p��9����}�����7l�������m��c���=0�=вKK�A��v�z����Gd�����"�l����coK^l�q�����]D\{��
1/F�q(f�pr4x�E��!�\�A?�~�B)�;X�w����Cn���])�Rl�ϹO���F1�P�ܒ*C�/-�n��������
u�ᵶ��jL*�Ϩ���/j�j�l�Y��Ag���ȗ�؆j�\�kPn9ɰ˵n_Z�'G�N���=�-�(V:A<��m�YǏ���T�����(�oX��f;}�7߄̨^A,�zjtb�H�DLE^4���[�Z�[h��Zh��Zh��Zh��Zh��Zh��Zh��Zh��Zh���_�?�K�K �  