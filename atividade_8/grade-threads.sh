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
� �r�[ �=[{۶�y֯@�Gj,�uqˍj+�{۟-�d7���$H�C�:$e'M�k�a���k��� ��7]|��V��H$���`Hy��z��_T�[Q�4�u�T�uE��#U���jS���G�Z�)�#R�?��2u=�!�n�O��7��OZ����m��H�����5�WR��9����uû�>���L�^W���rw$䗿9�W�V�������ֆZ��tۭ�ja����������W��Z�e���s{����zŇ�-"mw%���$��UŚ�fah;� �E6�.�7�`8K���.⚔N��.'.)�%�CvB���P�ca`[�`I1�z�D�a��v�?�����3�Ԟz�������&c�p�tL&��o˲,A�LZ���S$�%�F6!����J<JIY��~4�e�)G�������dxD�1��AH��P
����,��3��]����j)�o4�������_xu����u�RƯ�Ը���`'�	]{c��a��#r4�z {&����	8D��h��zz��,L5e{�g�>��Ȇ©<����p�;5�s�L{b;�a[����`7�TG_݀��pj�Y���}���b�|��;���ZőV�ܹ c#�x������3	�PE��1�!QIy�./�>@k�� Gdz}l��:ԛ:��������l���T
:I�����}���<8� ֓8�@ݜNLX͚��⦦K����M��B�#�	(��u��R�w�'-%Z����o��p6��`��`X�*#+UMCi"�1`-�AR`���<�yńk��aH%��C�@BvvR�e���G��}�/6�(H�?��GRCq
��l��6�J���Cȗ�cXސ�*}/W��J����U*q-�6~մ(QR��X��b: �M����"��W	T݇�Z�0�a��2 -��;�n�WYQ*��?Jى�Ba�e�{a���=� ���ՔFs��[EI��u�w,7���X�%���)��N����T��_E���K�J�!X���zU[�e�mgtkX��MM]��J�"�����Ĥ7����_U������(��߰h��*K�����*�Z�WRn��7>��{�P} #�>���Z-7��~���fM[�WQ&z��>��,�|�}>?/�1F8	2���[���ҔmO�� ��3L��8����2����d�3�>雺뒄,mw	��Qk��]{<��g����1��1�<�T�p*!/|����uc��_~w!a�ȅ�Š�n��΄ϒ�������b�l�HU�m�B ,~�բ�u��1tPK2�a�	�~�#cc@ZD�B����ı���j`�Q����d}0(�gW�u�+�{:!#�?�E�_�tw 	�x1�O�A���dwN����-���f_P|6^�0U��J�G�R��l&eK�.7��N{8O	�_*	C��5�����S�lS���3OF����(��s>'�p\چUL����}%}��_����<M't>�鄝���x�}L8.`!l��XYgzN�kjN�#���b0�#��&��`޾����ǷZ�;�h���`���i�Zb�oh��^�WQV���n�m�?uX��s݃@��A�s�`��2�(�װ,U��iW�_�7yǶm�/�-�8М���\hT�������lC���ե��	f$lk$�i�;�>8�lL79�O>�����2�~v=:�Rf���U��=<.�F�`I6�!�)œ��N�Y�Ϝ�|-�yT\��`3���x�I�}?1�|9�4��t��
a}��H�������]�4�j�p-��Ħ�s����.*�GW��㶈CW3ct��e3'��J6ӳ���9�[ 	���x��:��:�է.
�w��������7,X��>��)�)Ş̒@��;Ms��WLR�������N�_�}�u�����v>�����*��_����[I����@��IZ���gC��r\�r��2�wS�2p/p������ �!󿂱"��;v�����`���C,І{�nl�����碿#Fܨ�@���-��Y��iyL&�������S͐�	g82�-pbp� �;Ss�m�"��#'�T*���t5tc7	��н��d�.n�{*r˗��|&Fb��)8�3�-�9�G��}$�7�����ex�u�Z�t%n� ���. .�
Q@R.����I�c����D�v's���I�b�;��U�<3nu���3��?��u��X���(���O`���N�]Ss���K"\��يQ�����E��s7����fu���K�[�_Tnk��Z��������,d����G�=�:�:����T>v(�.	�}��e���o�]�h�W�N��ܼ�� f�R�������G�f��`����% 8n����7�#��
����6o�Cӏ�
�s������^p��<'Y�@��8p��t�C�;&�'OR�${��as�3 "3s��w��V7��a�qz�=��wgh`���QB��k�yV
k 빒5��h�q`y��LW�PD�CG�d �s��Uz7��ӷ��s-?/s쿢ժ	�_k(��������<��}*��y�;��/��?_;�sʍ�_��9�ߨV���Vo���+)���N={r�����#����;�He���K0�)n�g���ixn� ��ԙx�ZΈ6��`�N=���%ܮm����78�H� ,�B*��ķ�Ԛ��~:a�|����~� ,iF4�N���"���Y��Y�ޝ��ܯ�������;]U~��l�:�:�gݣ�Ցf<�&����?9§�WEXxT6���"�D﹞������.���kr��ǸW��e#&��&�Mc}�ʆ�u3F����-��Lѣ`�������6g���`��.�bG5	E����e�^���ϸ��{��N�=���'��Mz ��>G9g	��g�J.A��NRs���#BgJ�{�mR�
 �:�}��/�����q�*���gG���O�|��	��v�C_A�ۚ��g�::P�h�q��3���~������S3oX��.%�J�(�&�fU�I� ����ǖ%2�4VU3��xS�}�SȨ�HJ.�� �¾ƘI�������h��H�q�t���R.Jp�E�c#�Ϟy�)r#D�5��DX�q�+�7�,Ű(���3�X��%�/퓗�"&����M���73�&#�1]�Ġ3s�3,�0na�,+�'i�R�(X(�R,�-{@Ei�d!� �";D!?6%3��l�܇X�V��m����>;Ȇ��,\f�8�A�� Ɠ'%��_�D�ot�B�FX�#Q�f�$�;G=�t�O~:��{-B�Y����C�B�P��r�֣���d��4��:e����S��Zvq1-ա��ґ3��=%�������c��{��1��+.�8�IS-�`|2XwX����Է�g�tF*�lH���G''�n�M簋K�{�>_z����ǻ��m���J��?��?���YM����z�����)�����@gl��U�e����4����r�G�S [� h��O_��������ߕ��?�AٱFr�u��e�DG0��;�cǾ2�ÜX��E�s�;�auY�5�=�	�����]�I���3�98��*#�yԻr�x���C:c
"�. ��e�����Ij�d���m�n	q{!�/�N|�:�	b���:���|�:�Y�axN�|�T�+j�N��L@���J�	�S�-m�11|��O���D^��2�4����C���!G�(��YѮ���(�D�YUPx,����D�>�0ֽ�d���/0L�_d$1-�K�y�t��.o�ʭ�xAY(�7��0H���
�P����;8��L�JEgRu1��ܴG�!Y|vɰ�	9ň�14� e���Ey� ��Jg]gJ��^�gc(cL3�b�;b�p3dU.���8���ي8�`�q�Y�\US�f��;����-��O��%�t���/g���a� 4��&?W�#j��0*MM}���o���wO�_�ŗ��/Jє�(�R%��}ӕZ�r��}�2�^F�$i��G,���n�hx�9���T`�,�3@�$519Օ�dt7~?~�	����^ֆ���:~����h����1)�(���q�v��[��w����2x5w����Jm�����<�_�k���ʟ��-����W�jM�%���z������\Q��ݒTY�������������Na{�ظ� k>H��O[��(�����Qt���k�ğ���|l2�C}jz-	�~$bZR��U4��V���\���r�1�5�hP���[M�G�Ǜ�	b�06���-��ibդG����l���㓣_:��������$ߞ�$��$}+��u�Љ�+�I��ɟq\��X�ۮ ����O&�ѶD�fA�B��" �ܷ�B�y�{p���;��m�ߺG����N:{���),���AG탣W!xbL1����^�_{|y���=]�������y{����s���}��~[w��ڧ������Yw��0l�G�7ڮ�J���/�N������c��t��2�t��V�[��Z��D�Ĳ��r��� �Ŝ\��2�!i�sߤ�o#¦�p?��������H?�$���7mpm��U��kbO�%3W۩K��ݰ���턡i�&�9q~�+��^���t2{x�e!
:0�`�`:��>c`#���ς��ܪU�3`�O^ZSf �`K��)�>O貳����p���������ϻ�w��h�������&J�=���g�E����������[+���ƽ��t�q��iְc�tþ�?����o�_OZ�`L�,�I����4<p7�R�#�bmIp���`xu�;�-I����ū���'�I�!9���w�?��cJ��������?;�ZQ������4,0��b�������,d
6 ��Y��s&�wW�v�r�-��d���Ѡl��(ned�ZW�7SXp<�8v�	swE�}ݡ0]�k��R����9���gl��N�9C�:H�	�Y��A%k�[Qk���-*����LX�Ƃ7+ȉ��foRz0qhl��F$��'�|Q�7�D��'	��)	�7��MjV2���V��֒�),�*�i�[�h��Wr;�늡�B�C��͗C�	�Z��j��f��$���P��ZW%�+���t�>͓��٢�t-?��0r�Q|b?M�`b$-`��-�r,�ʳeZ��o#�2-���{��۲�{�na}��F�&c���2���V�0j�Wl� ��>�U5��=Vn��x�w��i����S�j�W_ϟRY/ut�2u��i�*�Wc���2�g.Qs�ߌ�w\s1o��mVb�P~X��7ْ5W���'k�p��9��f�+�W����ҡ��y��wwjUƆۯ�Y�>�2S>�$�jxZ]����X�0����bҐ�G�v�!s=�����ry��׌`Zn�lELخ`5
!gDY�ȫ�^�M�^�<��ѐ�F�|�ο�#���֗ۇ�7ڇ�K�CՇڇ��My��,�"���Rjw���>V�qkD����?��.����5�|*�V�:_I�������}���9�B�������_R�OZ?�����,�U!T�极<�:�n&8���ɷ$7$/���`����44Eaȍ4g�BN��/
�(�M]9��C���"P���V��g�o�V��s����7�շ4��}ȵQ���7�,eo�������I��R�y �O��X����n�{���9>hw;�Q�U�.�
2�������@�AT�z��i���I�X"z��.6xk�o��'����]�s�������f��ݽUƀ��ٜ�$N&3yU����)�A��`�����Z8�!�v�Nl�Z�O�V���b�������ѝ9xv@��_"����=�0�(����2�ONo�//o�7_}����?�t�Fg���Kk0uM��2�ͻQ��b��?�gB�?}��\�?�z�5�WO�����Z���*��ĵ�j>�=4Ǯ�8�1M�TK�hZ�E�H�Yb:ڮn���&zi�dEVׇ�V�w瞁��mES[�V����tc
����e:V:0�<!��!"�]/�y�n����^[����jŐIK�6u' \����|Oi�xmٯ���G�M�{��n_��w��^��!���&:r���]�R3�#2d�J����%2��&1`.�������%�u��B����VY�P�[G+�w�Q������+6�J(o��i�\B�)�1�<t���$|����(�j�#N'P�/�\$4� M�E�nۯ�cP�e�K7��3����Gk���C��!�F��v+� ,�bʧ�)��#��O!]OT�X��u����k�.\3�+����{F���"��,��=I�X��U�c�>N�ʞ?XNHtWG��Vv3���?5$G�i�j���}{�����EY̓^jŸ�.r#c��p�x�*���ٝ;f�t�D��}œ<[f0�iJF�	��xQJ��\�ʞ�'d�>7����D�]2��9H���ʢuk�g�b�)����"K�H���?�����ܸ�t��fH�=�}����"fJ#Ý�dk����
����Ÿ0)S�R�_�.3	ߵ�$>	cܱ�U4�����I�Ij��f(=S�#�#FZ��t���$A�3�`�	�8	P����;��Hm;��8����m�}��-���V�����6	�\��g��M��ԁ��+��Wk�(���!\/X��*������W�ܙ�=c2�˚��	�ە���e��a��_�@L2��N��w��ԽXs~�Md6�MQ{��w��!�/�"�79������_U�)��$kVWa;���gkRE�QL���s5:�?��W+ſ����'�? ��-�M�3,
ˠ)/�:���l~CkR��.����CH�{�{��Z%9�E��#�P�ٚ�6�/��5��p �q�6"yW;�y5�f�W�������F�Xxut����k�!S�-{�+T��U�8~�Z�~�<��^X| �A$�5�[]ӧ5����݀V�E��m�+7V������&ڠJ�-A�5�1=�2e␛��ǫ?Н@��dr����+��3��}=w�}R%O_!n�����j[����^wi%,'@�m� a�H���\�Ab��_�0���|��YcO���;��.n4�D�q����,��������d@ul�V5a�YOz�2)�b�;���x��;�ong����}~�E����N��5��~5�Jt#$��j�3T:-�
�U"S�[�@��{�a��c���,��'?�ש>+N�Y=,�`��/�Hx��U�׋���2��o��g,Gʪ^ؗƔ�!��3�Y$��ֹs�����{f�}%s��g^���Ib��1*�o����!����5 旸C�b��VJ!���s��V�w��.Wq#1*��;�}CD'2���f����^��,�$�0�p��˳������I���~: U��E��c<g�֓��a,��e��������o��Z��s���ڋ�S�MJ�kt*�jt|f�))P�o�j��+�N�,�1�n鸝��u���bpa��MG�&�D�s�~d3���/O��wW���fx�oX��������R�7@�����n�C�~��Lt�����x��u������q1�|��vq�p�Ǫ��|�9��Y+�'��������/���3�ש�_!�\���Y鶞_}?֢��jLزs�0�b������?�XMT����d�+#3�_)9���+�Yx�/<�i:ܯ�x]ƾcX~����īe�l6�ӣ��/���Ă�����ݙlw�>��5}��T�_|�Ӆ/��/WțB��?���"��� ��HX��ċ��$7aH��%�o���%�E��6�v2�0	ǵ���NWFw��Z���M��$�iU�[A��⬚�N(���=�Ī6�� 8����7,�^�̧S2��{�!k���6��� ��1`�J�4�J0n*{�:Z��tK.�Aas2�B�:����,�|f�Յ?f���4g����	y)�E��� ��
����uZ�v�[����Rm�U73'�˓��P�l�b�mpP ,�B�"�A�N5���?�	��	�����F�Ԑ��.V<�����D��SI��X��"Jg,ɩ��ڌ�g�:�I�M�����ڞJ-��uT����8�p������GM�cf��u�*��ֿ��V��ǌV�1����?��K�k��rL�9��݃1����Z�`nL���/Y���l�S$�=I(z������H;&5���{��:������iw$�3�GJ"evH���#����/���ALv��RH�$�x����E���Ԏ��}�Ӗ�>�bĥ3��Ux�ֲ�O��"�6�P�A�$��0��&�O�g��O�M$=����A�Ni��#"5�V<3��;&ꇖ��iJo7�Z���h_���2�(���Gh<�T �ﷺ���}�F�����7��9u�u�'�BD-��҈�\]�,R<�-�ė��2���}+�#%4$�+�"�M-G�*�k��O i�܈`#��)��ܠ`$=꼁�^���A,O�����G��Fg�G�0�D7��%0$�疝1��Y��ʘ �X�˨Wqp�@�Zs�(P�lN�I�F�շ�|y�B�f��,|�!8͗��M��D�G����B����̱���v��hb��@n�����q\lw�o��3kjEk��)�{�%2e'uw�|8N���}�>I��X�������s�-�(�$�W�Ȭ���P���g.��)}vn�Jt=Mn��N.���b��$��%O���28��/�}�12sK3j)$\zF,\K�#lF��@���&�2�<׫�5��ֈ����l��bNj��Kq8+��Fd�<F4��;���#ىA�p�*8Ĝ~���Ȧ5�ZhN�/(����9����&^E٠7�*�< �����D Ok4��R��Gû��������x�Xעշ���
�ݞ�~��-�~��OԿ���Go�<��fX���+������%?����ow���5%*ŧ������zxu9:���OЂ��>`�:\�W��J�ґ����������4Ǻ�����=�1Iī{���<��ҎO�1��B�-3�в�%ZF`��%������eθ�����utZ�y�.�y�`��wjWKd�!�2#KdD�Id����W�}���W�ko�W:��^��=!�gJD1Y�H�陲c��+�[�l
`��U��)��2Re!��yb�V$���Nt���������+H�̠��%�'#�i7S�$��G3Y=�IJ��w�mѝ��z����71�mf\����і�6��g���p�k��D����������	/�ְ�o'��0�U�������Q���}�}R.���;"D���ӫ�Rb�Wr
���.��q�r!ڻҐ�u�_*�ѻ�Z��[�X���)!r�?T�!qk
w�bk!,����%�P��R዇}[x�:-�C��e��ǩ�{t��S3��L�S�w�nK����/��������w�_U�U$"n:��S�B��>�ncl�.Y��l�Z��[�پ�n��H���}���,�XkڽxW��Ou?@�
t�/��+
�B;�����n�e�����1��1�:��:%�u�_TCS�`��#O�>nV�$��&Kd��̢�!�#���O���:�c݀�C+��������(�%̷��2�:H�j<��vǺM]Ց��[c��|<å��[U��e�Tp�?�JDsS�S�u�����ףo���+ue�+�J�2�����?��jm�G\7���|��)��N�jXU|����vi�D�F8��o��%�9Ƥ	6�<hoI(����J�[� ��n��ݎ"�%�EԮ���juv�]���~�oۊ���T�����J���뜝.�����w��Y���pa)������Fo�_x�����wF��!�T�.=4-�2؀[��zJ ^���)0xcν�(#ē����K,G�/�(�ɭ��y0�G�ǭ�t���|�n����fT�_���/�KTH��Ȥ�Z�lS��exl=�5_���&C�K�l��ǯ÷�
<$+F~H�����2[a�>Y�niT!��#�;������Nk+�7�Z�_���+nX�M��4?����-��;1���ppl�K|�/Q1ĕ�2޾���v��uY���̽��y9��9J�j���Ňa3�E�$_��Cd��	xR����+w���k��1�[�`�;"Vd;��MN)D-V�"
hk+�>� ����.D�S跊�G�\�OM���{�s<(S�XQ<�?��j�,`�R���nq�2��G|(=��# �;X��w�ۅJݭ�Tz+�K�������؉O�akS��M��AEO1��[���2pr#!=W���u* �Fu~!�DG�<�EF�1�_h��DR���6�B�_u@��
�QCu.�	1�s�o��s��ѷ;�C���m׌铍�c�RV�^�1�H��}U(�f�枝qΏlw����s�{�{�*p��OSՖ����v����&>U����+~kz�.sG�� �BD�!����o�}�td8j�Y���������uݖxˀZ�zNH`�&������g e=4u�t�l�	%}��X�1�r�`����Ѓ@7&�1�l�/	�d\�
@!	|�	���D�I�A7r�����&��u(�T
��t�n��Q��w��LML+U�|`B��� � 3H�n���R h� ���\� 
����#�[���n�݊��<��.�Ø$.��誄�"���$`9V`�v�(}���D@E�G%�F��*
��nZn)��(G!�qȕJ ��S!�d;��Rt�%� !S!�g��X��mzY@ZY��
a���-NlA����u��k�n
�	7	4���8g���#xo$ǤԤ����Ϯg��w&��B���M!ΞY���2n�."*�W+,) �;���I[(�J�Q�l�ED��o��vHVJ@��[p��=W�%�a��.rVK���׽7����%��iA��X�D2,��㤵AT�-�7*̤8im�/��q?Ff�i;��^��-����j����D��U����5A�r��G>M]��;}����m��1 �k��Wh�{:�������yV���y��>�_��zQ0f,�X�%c�=�Oo�kGJˢ��-�t
�^�8�D���맲�!<z��l��MGS��=K}Ǳ� �Ґ�:Y�o�{�[V��u����2�ɳ�Q��N�����l�m�S���[�?�<���ۙ����S�[2y���,��v$�~�X۫���d��UH�����v��?;���ύ|*��cy��'&ݙ���.3�=,�iQ�=Z����H��o�d����2�ƿ�%���n�������̍@����w����}�?g٪H���-��N����V��ȧ�����0�����������p'W#�@�ԭ\�f�lpq�}p2�;�ϸ��M5�ҕs�BvbP����#NXr3�,X<��ܑ�
u�r���6���������̈d�z�+�}�&i&\��Þ��4)(�[���]��3A87�j>
�'��ڑ�]��'[���&��^wDg{ؼ���2���G��Q6w$��25�4�4k�=���{��ojo,Gh��明����;��N0�e�r��2h����G�����TY�D�D}��S����;�T��c��c ��l�R�����k�J����o�������&7����ӕ���T[
`5Fx����g�#��{�ݫ�1c�;����؟`��qVW'Vqt��.�6�Y���3�
�������\�������|
��N���{3�B���>��$)�S����f�[L���{�0�����"�4�Ϳ��F8�ToX��@;X�{>y|�:u��[�����7��I'��TO�@��-m�yGO�����s�� �X� �`�`�Ľk�g�Tp},<�$�rct1�}���o>�Ł��_��������!l�9H�)p�`��Ǆ���g4��B&5$���y屠�o�;R3ױ���fy<�lS����; �n����[���Q�7|w���*5�IS��Wd��r�9CxZs��Y��P/杗�)c�JR
��R�;�$���uQ�c��{�
�Sh�֍*;K+G�7Ռj?K���,�xH~C5"]iiUx�%U�:V�2�Ն�o���~��G�O���b�� 2�˶k<J���H���%��Zr-S���N)�՗~���IS�	��v�CxS	Oڿ��/+zi�ObwHT��4l��5h�4�xi72E�&�{ǲ۶��?�i%������G��Jj�Y
ԅAK+��$�� M������^��ɟ�K�/���D;��\��y�pgvM�i}t�zN��VN����
?�ڃ�h�~F�_F��8��|�⸉>��,�CN���z��y��=�ܹWˏ~'����X^�������:�X{_I�t�1�g��J��s�w��?ͅ<�����=Sr,Â�k�de3���x�;��^G|Lh�{�<� q���" 7&ˁHJ�Y�;L���x6	]WOeD�/� �k	#7D�q��M�3ݥ����~P
1/�}�� Ъ�I>��=�7TL�ܘn�,;���N�6�Ɏ|������o�W���� P�$����sU�u��-s�I�d�v�3;z�5�ƚ�*C�a��������O���3zU8���f���M�Q�����I��u�ޛ̏������VyZh��W��@�����c���wj������v��{/%_�ϼ��ߊ�l=v�}Y��?3W��̝�3s$�LMj�\�4���$�`j���0��_z���%n 5L��9l��/�ѵ4�WJâ`FC�ΊŰ(VW� �+�A�ߓ��4VL�>n��4'ɺ�������Z~G��G�`<՚��EN�P����6�i�k�����H6�ZaK}X ���թ�[��-P��ʭ�vE��eg
)b�9^`e�J��Yc>�����:��罅D~p��B�i�C�M��w�n1�M��V(YgR�uPə�_7��I�,�L�Yd9(�
�Q�N��E/�%RR��C���A>�ֻ������Q5��ۜ��#I6����<���ݡ�u'�+�.X!A�N��=��&?�}����9W�عrÁ��mFo:��W�������^��+�VA�;� ���Bb?Q�]�����������&L.�����fguqu���/=�^~��[P#�����ØN�ǁD����\<w�k�,I��4���5>�:<�G���.9���7([58���v���TK��00�kP�<� 	�̭�tK$��4�#Ɵ��yo���1�o��.`;�@���S��,Y��4X'�N<��}�y۶-��L��8o�ڗ?����R�Lyx� |pRq�؄�T8g	[�����a�a�z���h9|�r���D�
"�n��<Bg��t�a�yr�����Z����ڇu��"^p;�C�!�14�R�}�	�����޿	����޻���f)�M�}�*����d��05���N�����	k�]�L
q��A�VP���~g�G��5��P}�b)����B�QS�*�bօ�!¿N_�ע����7|:q� � �*�q���� I�&�dm�e��s!U�1yx� �]<�� �$��O�;��0�z�� s��Kh
�Y*�1)pvx~���� o;PV"g�����o�=�,��r����QS�a�I��D��n��I1eH��3d�N�I_Xȅe���D[a̵RZ�w18�� �]┶2~�6\�Ԅ�й7��Q�`,r�8!�xҽ���������g)֛/��+6�G��L״ �\tz �ƺ��yZ�7 ����`�e~΅��~]�E��ޙp-b�Iu�!n���;�STK�uRi�iq"
Y�qC�U*�L��\�Y�WcU*L'�<nT�
BuXc��#��Z��a�$�*o���@t�'(tX����U!�(��9��oN�"��S�-�邑�c�v�T���(E)JQ�R���(���)�F� � 