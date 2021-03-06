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
� �[ �=�V�Ȓ�������½x�'a� ��솬�,�A[�H2��<�=�c��9��=�y����[�!��s������������KML�x@}����=mx6���ggc����σ��ړ������΃vgumc�Y�v$��4�퐐��~�r�y���'N�?�Q�M���󿶾v?�w�d��<�]�|o{���1o�76���Y{@ڷGB���������vtQ9����:�����v��Z�9|}pګ��_��Ã�ړ��~����O��zŇ4}R���*��_I�r�e˟�F�a�x>����N�KܠBH4�tBj�gx�D�	�@�J0 �AH�w7�i�����DԹH�(��/��#{cL��ф���dl{���$�:���J����/	Α<�hBل,D�$����JbJI�VY� �yв�g�ly��,gh>x1������#��
�9����l�ixN�ې�9��}v�?}�v����Q�����n�:|}�j@J_���{C��@ �*y�Yk��(��s�䈀M�1�ވV� 
}9�!���v��¤P�A�:���&��9�V��EG�%��t[����$c/�7�5oAo����r�*é�f�4n:�S?&�I>س���k�W3�C�"��(��?����T�lVa��� �9$�t7����.jێ	8R�+�1��x�l��vY���q�0$��i�N�$���ͷ��y�@XO*���9�JLX͚7%����(���(���U�U����T~~�}��T���ک1��~�
�ΆSC8҃��a�WY�jjM%^^Ӏaz��� ������S�yU�*���dU ![[��2�H2����r�c1
RJ��2��dL ��� U�{�M�<	=?��꣕��Y�AXOWU���j�X�>%��RD,C�b�8 N0�ENCpV��. �*�V�P3�O���f�|��V��V��;�J�4EQ��׌�'�����s�8�I��ŭ�F��'������Y���ٸ��w�,yCߥCbY�����>=<�N�'���;/���UY�jo9De���4��Q�����ŖR�N7���+3+X���h5P@΅�I"zf�rx��Bm|4
+�R�����u.l�����Xs�`�b��l� �Go���;�M��L��;�A�pX��M���AC�����]Ж�z)��o��f��V�����ºϯ������G[�^��\;�h�e ���g�ܑ7ȕ�0�=G/�a��T���ㄢj+�3sV4e1�&v|�e�3UL4��Q�������ԿG׽[���h�A{תayJ%xr�w�^��ο�3��3Q��l�7���]B���1����!���N-�k�9�OF�:qY�E"o��\?�i�1�G+]b��i�4�#�uMSu������t��bTΡ����Ӧ����&�׵40Ƿ�@�Z:@!�i�=� W{��H����$$�����DϊM`��$j��G�6H!�ʎ9T�U�&�Y�o6��T�p�{����aCc(;�ȵd;���A^����1Au�7��z3�淂`��s7s�hǲI�6$�T�z��G��K~$8X�oex�f��HFʲ+�oR��Թ�p�����X��s?ϋ��~�nJ�4 [ �U	���r��5W���ی���֦�'�wJVUn���3
"j��b.������]�P4%4���Y�FԂ�I�C�El (K�j�D�'
Z�-0���"i�����f�-y�#ߝ��)�QGo�7s��h��󸓮A�t��J&c6���yKxo���;���ף���P�%��C�1�����P4�[�hr) �!���G���M0U�y)�P9	�ExŢ
e�Wf�����(����0�w����A�	a��*C�f��+J��~C��pE�R4�R�f4��UU�3�,Y�9�1�sw#�%p\(��
)��~I��mG0�����J�y9�4Fc�q���������8B�mJ�*���F&�4MC�YՕh1���F�dt~�^h�9�@i��m@�J|iE�d�N���o���7 s�t����R`�q�����5�1�[�£����ic|Xo�{Dn��%k���cbp���������lz��;���O��_�\���>���֞d���r����'�5�Z?o���[�iL?0��E�m̔�f�M��B�|nQy�Q+�8%G���۫C�m�x���1���О�j�Y�����~�Xt4���'=�z}ҷ~9<����'b���b�X'���w���v�O�?����a��]��.������������g�g�>�'OQ�����q{�4���c�Hr(�Ȭ����{"�:pМ���0�4����X�^Uoa��8ӫ\�3��P��S�Pb�j9`R"��j�JC���7�{9�-;F�g9+6�b��["_��C\oa\�~�)�����a1�(��e}g ���fa�.���{���N9�I�I�x�������cZ���6��f�E˃�,��C�A���#a��b,���	THD�p�:�m��� ��`0j�0xe--! 2,ǧ�X
�Da1� ��)��͑�Л�,�6u%T�*�&�S��7~f���9��g�Wמ����?���w��%�z����1�L �������|klO4��wz�:�+��-�"����b!�I�Y!u�a�]Ҵ�Uh9�ԏy�����na,IX�8*� nU망���Gx橜�j&��� S��1V1'g�"���z�)��B��hť�h�`�ƞ��8f'_�ez������w�w������n1-���^#�M� vyB���qb=��RC[����,�\l�o�^n�g�8Qe.�L:���3'3Ӟ��L�@xE��9Ym���{��>��0��M��p�S�`\�mQ�����uS�	�� �Y��b��U��A�Ċ�+�Ϗ�ksK�<��'�-��y�����ퟜ�[W�b}�)���%q`�Fq�?�%�����)�qF.mА�QD����%��Y�~�W��/w<~H�?Hip� )���cW��A�ҷr�{'��������.����IX>"Օ%���JdS�-�7�ⴓ�`�\��ՑŦߒ����G��r�u�M���2UZ���C.@L��2DL�.K�(�ڕ����;<f��U�M���M��s����9�(g��u�0��q�����_��&yQyU2�HP�,��Ș�5����JX�G}E�.ON��A&��2�)�Ζ�'�l֢��$_m�m�=�
�>�����{J|�S�e�8��|����)��q����Ƽ�N�aV�M� p�5�ƃS������q �{@\�^N�*�y~��40�(Jd.��i}��t�i��}�Q˹�I���d��R��\�3Sf���8��b�ծ�t癄1x��	�����(`'X���z�T��a�n@&�t	��h�N��
�r��ZpXw~�JF�򸉞�">�i*��̦��o0"�4ݍ�+�y�@�\봂�����Ӌ�<f	"��M0ތ�s��N�K�TJ����k��("	mf ��].�;���ċ\�xo�4�o�+�k jW�dJE��x�K����R%�8u�$��.G6�Sz%��f�w�N/�<�%�-��L�?.Hg�ٜ���B�kTglnB@a;���B/|���2\�s%��
�j�&�"�q��3(�L;���Y6������P1����q�|d�m韥�Q��%���x9�bD��ҾE�,<��>˳��7���&Q�V��Ȓ��bG�2�����'E.�k��]U�{(��t¯�h��hyƘ��ѭ���r���+���4���E��x��"AFAK�7�}��s��X� (H4��ʼ���}��̖ ]��hLKm��$�[���b�Qq!�X�)0g���]��R����&oᵶ��\��(����}i�`��|���i���Gʂ ��P�����*�
��*۪S�%��f.c?�רb��p�9���I�1��(�7�z�R�g����w|��~���G��hb:����ù{���Q�}�Lf[�
-&�)��E�%����"ٛ���J%�<@qa�8�7D�J�Â��Lr�)�՛nFC�T%�Dvva�c��2�,�����?Ҕ�,d��
��!����7w^H��<3?���G�о�C��y�@ �|Xmd(�쌒��.���	��M�"k���G�2�-S3��P�4!w�y���y�D�X1K|o~xu�N{c���ktb�,���S\���r����'|�Κy�y�y���	4��g����L�A�`g|�d���E�E���7�V�xj��a�	�{1bP&���躸�_Ҙ���Qt�8`��� �c}��7����m�>r-��Ά��v�&nz�L��7;	��.�G����*�>�h5�)���)n�g}Z������f�ʝ�wr�D�S�`�7g-{�J�͵H�Ж|&%�l}&r�&4��$V5���`E�B�b?�4�=#�]7]V�:l!�E�M�P>«z�la�g�iw+}�������>y�z��yO����{֫���/@4���S�N�������1Y&{pl��Ĥ���N�Ύ�S�j	5�n!^l�ŗ ��.RO@����1i!~��C/L>���$>�:�D(�� �(0_���n2�R����$��ZΠ�`B��9F3����_ў��\�e)8�Շ
.dc�ٗ���ws�x]Ǵ�A��[؄�ne��W�l�s�Y�պ,�pC]���n�a����N�[������־��w���p��6ǲ2
oH3�frI�~�>纴\�6nn��5i��J�H4rf܏�Ik�.!D�Y�ƺ=	��$� �s�!pVW�Sn:�)3)�Ue��P��K&K*�8$ln)N�vSTeӥ
*�T,�.�[��԰�2��'Le���=I��v)�>�ũF�<����y@�wR�k!�<�=����kB`��13�AC��v�3��Y��9&��Y���e�	s6�2k&a��;S��?���$������n�uCv�
W��$W�Lf	Z�\բD�?�~y9+���ޒ�V��l�Y�� ~���M�y���ՀQ
��%�Y}nwb�E�)��J�F#�	�ҽ]��u���4�R�K��擨08'�X�F���Y���A�Jq�`2��b�d��AN��2�0�`1�ś�0�����V7r����u��}��𞊯��v�g�ꗀ�Gl���(أ�<>b1S�� ���4x"~_.ͮv�4��*O�U���O�E��0����D-#J��d�l��08���b��Ȧx�D0��/��A��(�=rY.=��O/�d�|��O�sI�|�y��?~�P'f�'	t=�o���Ot����Ɵ�D$F-u���X�B��z-�d!���y��|�x�|����+�hӥM�U����`�#L:$6������&�+�R�2b��[�u�s�5L#^4GCL��(N*�b<r���Ot���T&� �=��uʳ_��`zI�G���i��j�4U���a�WUf��:��rELe�.ͻ[}���'����w����>����ՍN��?i?����ɳ�|��IOg�<'��6Yj#� x�=�uCE�}�r�����io�M^e�T�Ƥ���w�?�U*K�Ex.?������#^�1��6o�������ߦ�%h�4Є�.@��$Y���Oǃ�6�T���@1�-�n�8 �X���!"��OvQ�@��F�����$��X	�m2���Ə( ���#q�ۗLB��_��>4�c�pl�/�4�/��q�8�9�1S��6��z�
X.C`/�x��j!=+�M4#�2��O���F'�e����P�iO�)8�;������`J���:%�I�ի]���='��7r[��ʩ˧̱}
4##�S��$��O���_�VW��i'���9v���H+`D����$E��F�)�4���1L:�J�F�t\X`�/�9$�=2�?1w�O�u�3aN"������5�����`~y�'�ې0[�M>���M���w5�mA�,��M�Rk��\�I��'v�A/)V�Zf"z~�@����詷^����,��l͡h�v"J\���7���Y몬�.?��n������P=����7���z���>�ِS� ���|׋�]��%�I�;�j�¦:'�P]8��/b��gZ ˟��~�cTT�j�'���q�i�������]k��+u]n)�usM�Ë�t����xR^\-�Jg�	���t��a��rڲ��ws��,7Ya�̕u^�olfzK ��OmiR�?��������0��Z/�����-z�\^eE���s)�7�F"b����s���C����Z�",�8G�xz���08�3��D��DXa��ۍ��"�(@DkK5*#��>MղP�0���G*�c6�3�1�_O�:_4�在U>�e�xGƕ8J��4�'�����Z��Hͩfe��';;@�C��a�}=��>	�F�;�ا-7�*['8��>Xe�����ҌK��A0+�ԍ3��mm �3Z&ɧ(�#div��X�[p�ц��|93%�MXRI�'�Yk��L/����p�sR�MW\�W�r	O w� ��Ÿ:fz]L�.��h��5�;Ыxg��cuf�/�Pp|��e� �:��d�.)<RM�4�'��<>�|���~7�YsM|�16\�b 3[fU��Y5�w�ٶ�e�Z�Ev)�SFb�<IǢ�G�n� ѯ�i�ò�,����*ŧÈ@NC�̛�*K�7}|D7��f(��>h��|i*Xg�2�!ֱ�h9�(��=��i�[| �W!S��Q��Z�77i& m�>?8<����B}R�*��t#W�j	diʍ�&w�����#{�M����l�d�8�#6ú�K���?̬]^M�W��0j�b�d?w���[�M\�S�}��7��wvv����{�����?w��ݳ�ɬ���5a}ҷ!��O�S���H�L�M˫��"�5�Uα�<mn�Z�j�z�n�LwOOg�8��ʠ57XnwI�O�\Gȹ~+�-�W�=8�LgJr-X��t�V��ڹY�<f��{j�p���7h��|��ίй���H�Q�����j[��ֵ�0������E7R��u���8}������֕��.���-n�/���g��{�)�y��5��.���z���WqЄ�����5�i�)��\��oD�,f+�|nH	$H� A�	$H� A�	$H� A����/L� �  