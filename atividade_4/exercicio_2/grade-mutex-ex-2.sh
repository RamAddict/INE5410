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
� �[ �=]W�ƒ��_ј�Hl _�p&�`���݁�#�6hǖ|%�����{�a�>�i������[jɆa����0ꮮ������.�cŗ��]�<�jO���u���\o��󬵶�bm}����z�l��m�?#�_����D�����^T7�������A0����}���מ��Q���_�n�6޹^�p}L���������֞��ÑP����~n���W.��r���YhU��g;�����ѫó����spt�����c������ϝ��
�i��� K���$	�J�ެ���2B��'VD�AN�M�A��hH�,���u��=d;��x/C꾭��V��
 k|M}@D{��Q���:$�7��$��i�����\/"��^���\�fFZ��%�9��M#������q�瀫$��4\���-�Ȗ�I�r����ɫ<B*��Y��o^��ecD�+>��MY�`��cc�i�?ʣ���˓���s��Հ�2��Z���4>� &pUr�Yk�xQ��W��9Ob��!��A�*�b4J��n�m&��F0�W�{E��B�S��Xt�^BM�����q��0��{c�� �A.p9���U�ǚ]Ѹ����1�l�	�~��?t:�UZ�ѽeS�������Z[U�*.���i������}Զ-p��W`c�7��$�ي��.b�"��˒��[�-;ɓ���[��i�@XO*���)�JLX͚7$����0���(���U�m����T~�i�Ӫt_�t��1�.|_*�g�H��5^ediP�y�5�xxM��AR�w��<>�b�WOu���U�V'�!����1F���U#Ј���Q�R*���H^�8%cXf��� �r�A�lBȧq���W�W��:a=�Vm�J�����)i�"b��>��F��) bΫ��$_��
�,��hE���%�D+�������7v�lk��R���Oj�oܡ�w� l$e�����/
�������_om>���x潁ߧ�8�9���9;:qκ�g?twr~r��<T{�x�!*��N@c�5��nx�|����Ӎ%�A��J�̉/��b�(�޵�H"zv�rx}��a��2VJ�������ll����&�`���U��I/f[�$��&Q�߹q��A�����yW>�a �_a�`le�Ð#�2O�>h˕Z!�k+_Ak���ރ�1e�o��ϯ�����G[�^��\7�h�e ���g��C�2W�4�zz1C_�j4<`��c��I��O�Yєť3v��6���9�b�����[^���A����躷+���A=h�Z5,O�O��������7r��"j�������RͶ !��5��9A%::nH�F�_Q����������,���R��:i�Ɉ�����}b��i�4�C�=�۶$�6?���SQ)��Ũ�BU3�u#�M9�uE���ki`�d�t�B��.�{4���!�j�"�V�F����'@$zVl�l&P�� k��$Pn̡�+�|a���0�fs_Ie�C��Y64����l����6<`1&�B��ƨ���l�3w����8��F3;�-"�!��*���?B�_�#)���x+�c���")�n���R������T�Ŋ���!xn�
�I��y(M� �A���Qu��k�x�	`1������֖�'}�;%�*7�ˠ7"j�b����Wm�P44�{qɬ8Cj�Ռ$�!â:6�%V5J"�#-�TIU�4��ooH�uA�:�s�e=��-�f��������5(��P�d̆2�!��f����M��@���/�UZɔ*�C�D�(�F �	B֫�'�5j�`��F�b�$��E3���dź�0�n�arߟ;���A�	a��[��U;E�j�%r~�%Fj\�]���f]Lj�A��yWU�:3ɒ���ù�qדQǕ���o���D��FqC�ԼM��1/��c�2��rtxtvt���l�R�J�X��f��IH����#�������	m4eP (�s�-(X�o��l�ى��M@H��t�Vr�~P;���65��F�3�`Uxt:}�P?m���y����`���='�����V�\l̦���i��|L��q|�Zpy��a���[{��������1�4�t|��z�s���&1}�\d�	�1S��-S4���������V�q�J�:�`��`�Cv{�ī/X9��h��qg��^��΀�ס�EG�����8�N������������t�����:��vV��o�9�7��?�@�{��c����������j�g�k�)��(�)�|��Iwg�0���c�@�8T�ʬ����D,t�9�_�a|~⛫�X�^U[�JIq�W�$K��P��S�Pb�j9`R"��j�NC��˷j�{9�7F���.�ض��acP[��ڋ�ǵ����1����] 4,�� ���oһ��aoe���	l�����)g6�0i�{rr*==|L�_[hh�N�hyу�p�<HSw(�m��+i?�2�DT��#1ٶa��-��҃Q��Q�>���3?��Ȱ�*bI(XQ@�f�A)ST�͑�Л��6uT�*�*�SO�W~���Ü�M���k��o��/���c<�c��bU�w�=F�	 _v88���ܱF��NQGr��.��*�xF=,�'��y���$������
�^0�c^(�>��m�%	+G�Aĭ�o���;�� �<�3S�P߽Ĕ,v�e�d�� "������K*���N\�6�j�������᫴L��:�v����a���{��-�S�A~�ke���.O(�:7�C�ǿQjh��s���,��V�����t��D��ȿ�2�,��gNf�=�i�́8�<&,�<�r��DqK�<��L�2����ἢ���@['
���������	�� �Y��b��V��E�Ċ�+�Oϟ�kc[�<��'�-���������==;9���@��Q<U?O����:Oµ����qFn\Аd1"~@���E`�~�W��Ͽ�<~H���Թ`�Xg�p�e�ҷr���������="�5���|D�+�-R��Ȧ�i;=�ޘ��N��r�TG�~G��M+� ��6bk�p��e��Z�9�\��
qE��:]��Q�?�+9Eswt�����A;��u��*�S��s"(Q� �x.��Iw�����ߺ�&y3Qy[0�HP�$��Ș�3���{�IX����4�r]����L��R��UgKړ]4kQ�R��6�6�PcX����w����vˠq|M���.=S������[��:;�Yٶ��Rk�j���<�� H��:6�J!&��6U�����i`�Q��\�1i}��t�i��}�Q�wM�<	�'���͍�ɹl3Sd����8��b�ծڴ���x����	��u��(`'X���z�T��a����A�>-dq�N���
�r��ZpXw~�JF�򸉞�">��oqfS�Y���4ݍ�+�y�@�T봂�����Ӌ�<f	"��-0ތ�S��Ne��ѩ���љ�k�	��63w.�`�b�E.Y	�7n���
���e(�P�-,���^�\���.�6���f~J���w�����2�cT�ز�����]b6�V�b!�5���7!��{���B/|������9�G{F�*��R�!�8>q.E�ig5�\f#H�Q<�*T??�o�l}�-��45����=*���(fA$�1.�,��Q���3?��Y*�WPk���D�bX��#K�C�=�`���S��$�$z,�w[�r���	�ۢ-����1���[7�+s���'��F4���Y��x��"A��%�����4�\b2�' 
[rX��}�Կ�љ��KҧC�B[e'	鎃i&T\H%�aKL��{��ťԴE1D,�	�[x��d/Wc Jfan_"�������,�|�#EA �l�Qy��g}FTW�m�)�;p3����kT�]U�˜_�f���FL�#
�M��T��xaU�Q�ﰁԏ�g��H��6�#���9�����Չ�7��d6u��b���۞E\��.*��yi�ʭPb�����S~aA$������	P�Wo�a,[���ك��y�[�ܳpt$C����
HC��5�*�6�``n���B�7���18g^H=���̛X�\���TD�3Jf�Hj�'l��4��I�	�e�[
�f(M��iB� �vF)f�0���L|�xu�N{c���Ktb�,���).��9����>Ug��x�k^�/�rͬ���9�b���ǲ���L�����ȱ�����|ЊO�L>L6�pf/F�ư�]���ԧ:2z�3�X!�E~N�>��ǆ�eŶU��m�h��Q��%��`�|�v0=Zm�G����*�>�h5�1����7�e��-et�`b�Q�r���*�{���X���e/V��\��m�gR2�ַ1���p0�a�Ǳ�Ѯf+
����xvI�f����]b)/"m:�����)����4��A����G����|�������������C痝��/@4���S�N�����1Y&{p伽�����N�ƎGc[�j	5�n!^l�ŗ ��.RK@����1YA���^�|ʑ�I|�5��P~WA�P`�����n2�R����$��:�K�� �S�f���3��=;�߹p�b8�Շ
.d}�ٗ���û9����cڟ��D���6�Э�~�p�g��ӖqV���u?}��}���������������d��)�p�p�c��Ҭ��\���O�.���ۏxMZ:��4�����2i#�%�h�4�<��X�'�wu���v�0��Y0Ŧ�"�2�YUvxs��d���q�C�ƶ�i75AU6]�P��biui��_I�>*}�T&ؿ��t�j�r�jN5*�$mY�虜��B|-x䯜*���E��:��-1�7��2g�,�sLV۳
m?�.1v9�2k&aؗ;S��?&~_I.H7�����uKv�
W��u$W�Lf	Z�\բD�?�~i)+؆�voK~��b6�,�|'�Q[%[�����ՀQ
��%�Y}nwb�D�)��J�F#�	vҽ�F�:j��|N1�RE���$*Ή"���9��k8�Y)6&K��3K&�߻̉_V�����(ޘ��C} <��ߍf��ߵͧ��1�SQ��o�sމן����r�x������i �5����u ơ�1�Pv2d�l#h硣熎�����X�}�x/��������G5|�I"
2�P��XF�h�� ��s��;É���)@�&��0���^��A=a�%3~@5G]c_r8�C'I�4O�K*���L�T$��.'�7/���~�2����������zk�(��A&P�E����!5,<)�����'�Ɯ���I^��g����W�?�ap.ሉ�Z]
��7 ��F���q��r��cM��zC���FZ���J��nrR(1q�fB���Dm]K��#p������F��dC��Ϡ�gPH�������,�叕ݸ�Y�)��-{�a�uq{�b�mM�z�խ�\�L^�4'&w5�� kd@��������3��<z,U��sʅ�( �73K��Z'b�pwY�Ɍ(�5?n
t�
��<z����lvU��2܁��]51�2ibe��aDٝ���#J�Z�fH�;���nr��� �O0_.�@��|���-Fig��>B���2[�D:� ��{�b�u!��}Ӕ�H�jb4$��\�����J��&��.���Kn�Gb�R�e�[��U|�}/���K����������jݦf �L�M��}F�l
0r��]6I�}��-//�9Q�hщ��8ؼ��ފ�,%N��U9�7ys3�/|�y�j�hH1s���~��r�b��1��'˔�¤��p�u1����l8��q@|�D����Ͽ� %�󛭛h���[dqy�jq�M�pL���bn.��V�0̖�>7ւF�.�g,tS��}�+�1-Xr/{P*e�4�0���(�4��М*��b��\n�C���q^if܃4yT��|���������ϔ��l57�2����O���x���L~�Q���� ��������Ц�#۰,��1r�Rޘ�����񫳎X��K��Zl[�'����+xj��	�LC�׆�S�h�a/�����7n?[��q���dF��^,0�l7u�ԅ�q6ŢH�D�5���4�����O���u�X�ËD��[�v���mI������jp�Q�� Z��hV}��X�O��b�(��0ED1=�m/����,��:�)5۷j�-\3�`Ի���>i@�(٨����ѻ���!�QsQ��IU�H2��~�ۖm����؟�i����>�[��pw���P�G$WD�A��S�?�b	K[l��o�#A-b����>�����?��e���{;������ߺך��QnӶ2y�w[3��i�N���ӳ�����õ�U�~m�6�������U�_=�Yf3^���6Il��k�sl�?m[���m��kt6W�S]`�Z`�8�������r�7t�_K���o��i?����5��!.�`�_��Y��.�j`g��T�����N�_��b�!O2ٞ�v6����f+i^�Q���w9���`ןY����ҥ�����KճĻ��,�C�j�����]��Z|�Z�Q�U�]gfc�#�V,��(޹���5�2mr��!�1Sֽ���߂6�	���F\CXS��sw.y�5���v�.rhŮ���4e(�d�4�Ͽ/�e��-Q�q:/��J�ac�K��6�O_�R 5�Ƥ.�
��SE���������y�}�п�/�	3�a1��j��bX4ר�L%nW�-[Yl��n��nK����Y�?�Y]f,T��[Y���ɺ�<��wF� ��{�剖̤��6�t%�L�l׭c]�*lk��o�nx���T���з��bJ]�>��`��W��]�:�p�.Q�� �ִ�������7^3J���89S�V^ȅ�O�es=v4D+�L����Ǜ�٬2�v�[��}o�t��Z�Z�7]����(V��l���o��ߧ����{;{����<>~��tl�ӰO68�a�s�IU�8���ฉ4z���x8KY����ѳ��1e�%e��?L�N�|)R��K�B��ߗ<��kIF�\��1���P�:�EȎEz���x(P'�p��e����3����ygB�L���@�`m�5�ov�D�P�J�7Ą��cSR��*����@�Nug�k�NFߎW�z4O�^�頭D-k�A���g��B+�@�-�slX5���(��m�'Ly<�Q2QA8����&�m/�<�E60��G?&b�L��m�s3zO_R�u���#�x����Y�����^�2�C� ��GI�;4s�XΛ���gSQd�>?�t���*�x�^���3�AV:�kg�a�(u�%Bn�	/��F�� �bߖ'jGw
����-�V%������_.h�H�)'������xاL'�]Jb�ъEp��W�#td�Y�ɂ�պ��a�M_Az`s�w��o�p�-���p]́�ͤ��*o��R �AP� 5%�J��M����b��'\	,}B����Y�z���_�<�ǈ�q[Qm�L8	삃���N.�`[)��;�vp1�.Se�Ց��o�U6X��$��ы���*��5VAл�$C��^g�Ls]m�H�,����M�R��+��Z ��q��P��O�V�\�f��E��H� cG��Y:�j-�+�3N�6d_�JZ���6G��������1!)�2E��P%����g,��Ht�0D���(���i�&%URM��=L��?A���������g���Ԑ!>�dMx��3�(f��`c�ye�oh,ߨ�[l �x��B��w�,��ji���F���q�O���_det|��~� ��א�P5�%���`�/���.Q�٘D�m�o=B��]I�ח��Q�q�[��-xL�-�BK*תT�y.T��������.���)
Y�H�e�v��V���!U8�x��}Һse� �Z�k��X��7�6�y�g)�c��W��U��Y�`r*��y�D�$��ɾV.cr,�h��(�䒎~�5�E�Y5򊖙�b!�e�.����0J�����;�3)�-ǘ�qv�̕E����(��S�Tn�N����p�S�I9��y	v�ECW_���K��;�Y!�	��ĺ���V���|"
�N,8)2���)*����#�O#.��+(�X���\"۴�̩����G'?�*ʂ[�Qe�Z��Oz�c)�R!H�(����#k�u5�REt�$��,��n�U�O'&p�n�ucx�3.}
�9�\��;�����<x����<x����<x����<x����<x���7�_ ��� �  