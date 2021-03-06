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
� M�[ �9	T��Ժ`�ԭ�z	QIA¢�0�$���IX��-����V�ZŅZ��֊�Z�]_�֪u�7�}w&		೯������90�;������dL$���q��._���]��x�].2��A��{�ú��?(��y,�]f�Dr!td��y>܋��?�Lv��hZ��)^���?��o��%W}�k�����Z�ˣ�"�շ@�����<�������'CK�dL&/162T �E��R�C~���a�)��".!>:TЛ%�G�*�a�A
��U>*,Dv��C�u:��6"-�RH dȱH��� �C�ё�	X��h`��fǀ�fI"���)��U#�s �)�� �̤?�f���9���z�6�Ĉd���T4�Z���@���T*�öFye�1܀�2��6B��q�)��Ud"I$!U�fka��/��g�S9�&OkB2,����"�c|y6�7�@R�'���2|��ž~����������H�"aX
N6/��x8�R��h���z�6D�0ZJ�X?B�G�	|OG�C��p8�>5I�2e��������=ȇ1��F_�K�[	�F�1�L
L���6��4�R�y��p����S�)%�MC�$J�2��		E� �ʣc�q���YD"τd�0`����@��p�+��ɐD��$���V&u�׊�ͼF�d6Rl���#Y&B�À����-�lD��::8�W���,�`)9��{Q&���.�A�0nRǐ/��(�\�+��z�q=���	O	���#�B}�_0�oM�8�BA`Ga��~,[NP~���w�w�`V@wpCޠG7ᢇ/��E|+��k{T`�����*�Ɔ3�^6��/V�ؑ��ٓ��7v'�L ��/.G�W�@�5*0��I���=�~�4�����".J�����|�"Ƣ�*d����C����E�ƇP�BrQ�a��zg�k1�L"G^�O�����G�%�0�D��83�o\u�����'�4�9	�'�2��=�_������������_r9�Od��\�Qi�
ڨ ��Lm�R���89Ř�$Bg L��g�%����	�T$����Sbp%���V���p�a×�q�a擌=o8��Cv�S�c�Q&l���cc@��.U�~��	Q<O-�ԙA�~�I��fH3Ü״t�%�e�ƃ���J�F�R�����W/���rv����˩��뺵�H�#���.�I=C��ܲ��~%
�Y�L�B��p�C�Y������J� ǲ�|�E!VPk����E�gEjS��[y�(���`X�ַJ+B_![M�d�y��c���� �P�ެK5n=\pl�ݵ�6�C#��ÍWl|Tl���u="���;#"�&�W����@m�:�;����ύ_uO��)̩�s�("��0^B>�
2�nӌ��f�\�d��̠�f\�i|aC�#"r�v����U6IS�:��F�eHo�B���	��p��E%&�H��"���}�H%����J���֡�Qm�V��a�M�vߪ�Ar`�H�L�њ6`+:��D�$�S�������7N�� Ud,nZ�H��e��"��-*��HN�!�(�#\���h`א��E�&<��uX\1h͔	\1J��`����1�bE>!$B�yT _rJxR
�K 
"��:О}��	mb� V�V���#Ye�^�=�1/���Z���8�;���^"a�T�,�h���Ӥ��B��0��W�g�D�4n���02ņ��!�c��8�@.0�\ژ�g9�ל�a�N���u��L��� ��{�-�h�N�3\6���H��ͫHJH ]ׇ�~� �wڔ:���ykҩ�d|{��8�a46���҆���E���e�^NE�.�"O��t�j��FRI���#���CkUPt�IC�c!����5H6^ʤ�\�Q�hc>��B�]>b5)�o�|D��3!K��8�a����"U<2��(&a�<T����$aN'gGf�&M/�-��_� �uȤvLM'^v����P@oas�a��MX�9C���B���!�]=Xۏ��a���F�	���䜏g��(���X�lxA�Z�D���r�UҠ��fm��J)J�����R������Ӡ{E���I41Ĥ8�R$F�b<Y�`�\UA#=M�t$�H.��l�QQ8�����`�F��8Jn�`�_�4b��i,���/X���>��?�+�[��*,�a��^�^�č�vn�5�&�*�7��q���TX�6&��Ptcȝe� ��k!�c��a�Fp;��g���gy��T6E�Ru�bI����8�Oz���$��P�2HxE(M��i��6� ё��	NZ�-�s��gs5���(1N�&#dyȹ��"�����E�
�R�2���R\���~Ċ��"�w<��Ѫ��hM@� �T�!�BR���N����7�g�m�7@���{�@s3:M�P	�HH�j�"M��4j;�Q,D�0��D<kag���:���pkn3�S�F=tT����y��rҾ��Դ����3;K΁��X6�	��v޹A�5�W�7����:����u��)�)��"G ����+�S"�����X��t l=.'2)�Q(R��)��1`����$���[����k��Z������|�A;�����$:ԡRi��eh)¨���ੂ0!<g�)e2�})�!ai���}P_j��79�*��^��)|�;NM,8S��$3e�'��8���Sf��h_���seaԚ�����cnzsLb��,8+�=7q_ص`�ո��!'n�m�ym����[�&ܕ���0�9JS��m&�@�;����~�=$f��l���a�#A�N���v�,��#���c nnJ�*�8�ۦk�lS���l����I=��$V\�g%V��#�U��1�5�x�&m\\�ar�[{���؁�����X�����qȼT�W���~&f��3	�:n����k�uWw4��D ���7��S~j����G��ѽ���77gM�|r���e�YE].�
���f9\+�W�,���9���.i���}�Z�A�Ut������6]�v���O�a�S��<��nɭ�;��嫉_�N)�<�JtЏS�W�N*��]��|СI�.Vl�򙰶E��;��<��4��=���������5���>�s���5�������F��T|wt����r��{<�`���o�{�Q�'U�|c�f�{ͳg	�TP>���E1g<����WEm|�{�<�{���X��-��(���٣�Ũ�>����8`�6����-�_yo�y�9�ީ�p����3�u+�z�)���x�s����q\͉7���=?q|��n�z6/J�9������՜�:��=m��;i�s�jb�=>n����%�Nr��R���}x�U��HΌ��{Nn�6c��]J�3��.I��ja��;A���6t����nF�t��'����g��y���,�[���Ά�+*V��T�exe��9��On��`�pb�&�7���+m_	�x?��w���j_���qao�AS/�?Ѷ��oT4{t��7SUe�e�"���&���,-�_�=�P��E�d��Ι�y���]��o�+�9�l��_�/!J}\$�^����PP6��7��>ߟ<:���];v�Xzsx��5���\���^2�t��%v��[gʛ�iw�{�lo����t;�g=�^zaf[Yv�5��{ߟ���{r6��'�dSCK��*�H�]֮��u��-I*�5m�7w$�fڷe�&�L�wx�i������욠/�7�L�_�S3ҽ�|7M��[���*{��݇_�x����U����%<iBn��U.�Sί[����7��Xya��6S�_W�������v������cyL���-H�����]�?�&�{�`h{�G~ni>�Ks�{%���uU�Ͳ�,�p���&�]zxO�|�_��G<��Uy���ן�+��wC��2q�vE�	+�h�6gAa��-���*]H�3S-��`���r^���g������i�%ߧh�쳅�jsC�k�����7y�1��7�n)�[SQ�S���~qW�ߨɨ�8�A�<��s)�h�t��Ӊ;�vt��+g&���������C��J?P�y̱�.n��c3���l�>��깈�nOܔK{O��P�IEU�wv����g׻n���ɘ�_�|�~e�&��,�|�Ã'[�������e��]�7���;=����^�)>�_Tp~b���o/+y�2F��{��mtUY�#,��E�>�7�F��я�_�~��A����ě�L�n����$|�܉K'�=j��O�ra\�܅�GPս�Wwn]L5u]V��E�5[:}�dJ�����~ե��7�ڧ?��kg���˪��-�֨�>�\��E���3�����l����g�$%�FM8��\�th����2\mvj���/�jZ�<�6be���e?jv�X��=j��Ynm�ZIp�z�%�}�~���Y������ȩE�����_P�O��t�O�[�Oͬ��yx���'��y���Y8t|����Q��M�sS��\(��<*����+W���������ww�3�k��[�~կ_ϖ�_�32grmI�A�s�O(��&}�����=��x�����극�
��֮�á�K��9eM��%�۲yI�ݚ�kZ��IYB��U���w�IPt�����A����]�|7�������?����k)�;y$$�o�}�N�)��\���Bsu�W%���$�"^;c̐ž��ɾT"5y��{K�F�+����E�{v���;5!�
�g���/	8�y\�QW�M�O���~cb�F���l��ܝ�4�D�=��h�{'����{�TTHn�vI��R�P]�oڹĩ���-�-�Yp������s�����k�݇��|q��Ia���������t�K˻|��s�T����);/?�Q�c�!�����Ĵ#m����V�P}7��;����}{h� �0���Ll۶m۶yc�v2�m۶11'L�v�>]�i7�,�o�6���"�aS�,8� C a-@{�ٵ+�u�Na�ܛ;L��i+��'�T����ޯ��#9����*���m�)Bӓ	��(������O��J�+����x��C.k�=�[�ۼ[4���Qd��Eeg�7�-�~��-�5x;�P�Έ�"S>M�
��Wg���㙠���9�����4 ��M���>����Β��0ƥ��ţ�Ho	�@M{�}h��^��M�N�G[=�z�Ff��~�Sw�x˗������[���+�ᾯ޷����w���S=�R�)T�ۄG��3䇓G�m�T�(F�<)�޹d���;v�������O�����W��2SO�j�Vr���$�M��/fW�l��W���(<�Q&��줔w'�����t���z����]h��%ۤ��x(3EBĵ�)��jQC_�Kw���u��Z�RZ�nX�P4v`G��IxQ��K�����E0$��cT��7P���Ue��t�@ �+ܰ6�79�ě9�z���V�����x�O� �[ޙ����D��;H��&�M��%,d7�«ʘ�����R��:�����<�f�K�.Oy@:��.O�u5c���(l��D%yoon���_۟3IfA�z�Qpo�ӳ��.[$g�S� ��HH~gx��&A���v���?�b�Y��ޞ���-��d�1�6�kZ����F̀�"�:�)�ZX��R���W����b|�fQތ�@�8rӱ <��zR��v����gg!Ҩ��C̽xJ��F��i��1�h�o��}��fX�t�9^�&i���Q������tqw�����S��1g�Ԍ0�&�u@�]K�m�Ř?p�w�A��7�o?�/��������g�:���v����ց��?�Q�]�~Ο���ϙ�wſ�OV8<����0�-b�1|O���uc��>��u��Ma'���C�z	t6���9y�r�B�+n#�������(��PQ3
8�k��`k3ޟ:">N�`?�
P��4u�����Oi���#�:�3���A��A���x��v^#����ܠ{�����m6~MNV���U��-���&�	�!q(7��5:��c�՗cM���p��ć"j��Y�������b�ϼ6fd !b�.�Τ�]�BG.�.&���M�6��ȴt�gC�VBx�}26X��8f��������>�E��}5�������Z��8�j��S�v�"�l]r:��,Zn:���)�k�P穂���]�T��-�^��Do��M ����b	���G�H��Ou����N�ʙ>�	ꢵ����FFǦ
�I�2Et�V�4`ATCj����8X�<f�]z����N9+�r�̙ҵ�IG��ŏ�G���A.�7��T@5H\�.�m���/���{}��L	��s��?4��<3��!��0w��8�A7��4�Ĕ��p��z	x�a�V,��,9��}�EX�ͪD(�N������Y5|FP8�`�����ؑ7�R��fK'm��
妥�����֮�nV�T�WY]�A��`��Pۊ9�f��̪����	��4��������x�1����d�Yc���`� 5��F�,���߬�ɿyE�6eÓd�1	\qi��;�'Ι�;؜��|2�\Y���oLY�Q���Zk�߭��J��곩)�p�w����:�фͧ��ٿ���ܒr�{s�b��Q�'Fu��<ۇ�\g}�"��$P�TQ��5T���^��{����?\��璲j����A15d�����*���������ű_`�󢁑�Y�IM� ��M����`��P3��%�o8be9sVA�� ?xi�X�� ��ћ�����w,3��3�d��r�I���m�(o���ʫ�9D}k���^��;���u
�)�H5��,v
��7���A`LE�Рq�V��A0�E�fzTcY"��f�4���4�oa����U�y�c���i��"s�x	h�	K��8��?4�t~�uZ�]�%���(\�Tp�q�gߥ}?��}����4�.������X���	��O�m���_�t�|8�Y��H��z���U���S):X����qq]a����;Z�]]�)�2|S�G�H�ŲS��HQ�AQ��r^ M�����d�k��*�X�Ny)�X�QH-�B����p�
�UC��ؘؕ�v�ц����O�´��"k�Y�u:��e�|qC� qCG��f����|MRw�(�d�	3V8i
+�a��;J��8���`�K�%�
�A5�H�>-�N�(�����_�r�L0�Z,���pʹdR^�7P��`!���
M�S�'1�}��<ĊB�h�	���܃ȆK����U��34���j�S��U�8��v7�;3�o�x�cmX����B�L�4�Tۄ�D
�����^,��X1��pW9�t����M	>M� ���������у���H9�<t�Oy�朼�R�{���=W/�� ��u���rn/QbiD�(��J�dYv'�a�ߏQ�U%&sp���%�6�A�"�cN}kdË���z	�}�;��A��0S|�;���[����J	��V%j��
�@sGg�+��\�P�|�r�+��]~y���4g��A���p�k-�ۨH��zb���蟛D���^!�.���16�z�Jz�e*$�S���x$5��k�EJR�ަS���Z�#������gi��&��u',	f;�O��¤��q)%�»S_�5����]�)K51�yh�
�G����M�4�&�G�z5�� �eU��|�y�3B�(U�r͐�P=9j��%Y��wZ#>������m��X�^Ut�\I�I��&;��g:׬�+Q֬���-���iXOY��+�["�'C!]�|ű[�|G���H�e��`�^ʼm�p&@�Q�7�я�-L��w�e�'kq�ɔz�2,1�Y9���:�7�ϼ���'۩�&��j]����U-!�6�RD�4U�:��aG6e$n��B���o����f�9}��^�Ғ�Bn�L�N>�<U�q�<���e2��Wuk���ebڰ������3��M\4\��pr�1N�;��.���'��r�"�&܈\N��n��[J'��nT,7�S��0�9J��-�/.qIts4qlѝ�)�.���/��J�#��s �C�(��e��4���UV�%�����nҋ�l�����m#�Ny�fB���k~�?�K�G;�yf(lt-�����]�KSD�)y����pC��M���2E���ON��b"�����vX6�_zp%�*U�sΤjOeŜܟl��� ����3iGx/��E��w�t�� )gʐ���t
�=��߻�j�%Y�ߙCh!}aT1*r���A���#ո�	w�	��Q�Թ���Q��#�N,����K%��ʅ�0��p����E��ңO�����tK�3OB�'&������W��39���IM�)�#�b_e�����x�|�.�r�����h��N�7���ӧ$��rD�a֝���M�ɸăS.�4����lO�R��΁���)�T��>�|��v�VH�YH�hl��^7Fw��������������Mch��`��c�FCc7b�
̠��A�\��C	�kҡVf�`�����}Iy�h�c+�!��,?(�������I�S�6���læ��Ө#���Y����T`\����q9�A��;�����O�b&���H���n/�][����H��"���A-##����;��$�����V>vBd�� �����_ �:���}�ap���H|�R��d�Z�u������E�t~s_��[� o7B
¶
f�I��K(m��ʛ�����#�[�C���5 ٹ.u��2���b;Ѯ�bfRov����[�1y������%��5"�1�wL6���Ȕ�V0n�>9VZ2�e�G�hz6�F*�F'��7��k�e�z�*�* ������09��yIr�g�Yp0b�Y�o���{�����O���5����^�>��`�úۦ�I@��:�˭[6ݤ;K�J�Mp�	yd �L�	5įR��p63�<�*Eu$��Z	�ح��6�� Š���CI���@PFV�?X�=&�g��m.���wU�"��8�Q��3(��|��y[,+�?�4vd�P��rDm�� 	����5�lq�< �n��Lu���q�Ѳ��u�,�t���v���'�D��?R�E~�||�������_'���ct`��~�c4S	�E�U�̀,V�M�q0�v[���̸����I�Vg��w�,ԗa�r�57E ��I'�D"P�4r�F�v�O~���T��.�v��^�p��m�� Z�kx���?�����R`�����Ќ��{�'�AY�Ƥ�œ\/��6��tsZ�E���u��vt&�F��S�JaB�u}꯮}��e??%Q�kg����9���nI,"�{�=��Ky���]� ұ�ev����h�2�!e�t8����0����o��rv^xo0��$�같����S�M��Y-h|�s��L*��p`��+�Gr}E���"@\#"t3�@.���R��u���6^[[v��B�������Nź�c� �]�wjQ��:��j��9MOEEO��k�-�e�5=�}��L�FQ��T�ZY�yh49ݑeg�}���r��ԁ����G�/��mq��4���
GD27xڏ��̯��O�� �ø�j�۾8܏��ڰ�}Bµ�}ˠސ����S���n�}�`����>�]%�$w�Y���>�M$~�0G|B�ёF���ϐb�wL�\��?ڢ@���/��� x!�#>:����g�߳��Kh<�:X���΅��SV=n���k)�!�#ӿ��vB5��J�ݥ�Ec���(IDxTm �-�D�Kwh�0��$�"�D�*��?7̗j�c��	��Y����
���Dg�K�G���Q[~��A]��h3Z��4�UcJ�ᗧ"s��F�Z�@�g��M&(�B�BE�=6�r�EG���%klS��?6�IʮPZ�=��NnnyV`(|�NI�|���F4J��/�y2�/��ȡ���
iv[����B<}آ�N��/:�}�K��j�#E�KJ(�}��Z���d0	�U<�eZI�Ăz�=9�&��-����!_���1�ޝI����q��������gݸ�fҝ
F}���.���F�Y�����r84��^�[H.58�i������X3���4yFC �P&��"Չ�e�擥A�����ZB�q�?�Qj]A���9�1��Os���*�۔�����&@���$�VEEr$�K��쥴�b�T�T�dמ����l�`ӥr����.#<pW_�#�Nخ�Pj�L0�xHô��BX�b�G5��"��Ii O�6Ԗ)���x�|�caD*3��WjZY���I�NR_�^B��$��[��NzN��-����ژ��srnM2��g�P�24���3�vi��,9ƌxZ
Z	*o5-Ϋ�>��n�Q��1���\��I�c'���^F&��y�*J}�;":>e������Q�fw�~}[�x}XE���xwqE%��ޞy�]��#C��}Qm�0�Q���X���؈�0�F��rC�.s��2��
�W0f�bh��C3אPك|-�@�|E`tコ�[��H"(�I7SB�
��D
oV� �����5}HF��X��W��_hd�B����AGT��C��]��교ä�j���E��g~R5�mC�YB�դ@a�:����@�J�d�Y9��T)�}1��%K�����-O�z��(��p-$3��(��;�^01T�]��F;�Dҏ�BcP׸�FKk�$+aT{U��G�Iiޘ�ت"�Y�@��=�g��#�r�ז
z�'�Yq	�z(2	e&v��ϸ�%/WVDY�L���m�ǚ�HڡxW�h��g�4��ul~⨧��v�k֍�	����{���i48�Sk��˻Ҷ�O d+���&WH
�e�-	?�%0zlqI�6�yH��Q�����d5���]�/���#����X���[�>A���=8�w��}:^�E>��k�
�п�;~�D=���A�,:�����@!+PO�y���bcƃEBQ<�O4N�y��+@ͥL����'C�ӅS������B���j�G��=Ƹ~��T��#zI�y"�Az*8��vʹۼ{�t~���Βp��f��S�<��&_���9  ?<�T��ˁ}!Cn�����'��4�:��[�yy���/N:Iy^|��?5�|�H���6��gȵ%#�[��_��j�}�D�nҌ�F�'����f�ڇN�b���^OR	���8�
1�~[����ad�Lx��DvW�|��vQO�~ڛ]��l�H3l�]���aH�?��{�q]?�%�r�v�>X�#D�hu=�dP??f���N�g�_�,�0������|�{"��G�#�Z��tqA���R�7�G覑�uGr�ac�዁��Ϛ�\-��<pw՝��I)ٓy4b����hj�)�<@cΘ�������*��`���u�\{���wt�0�~?ӡ����v:��燫��pU�`��#v"l�w>���,+�0��Px7e-���^H~�=Qo���J�Ę�"8ٿns9�T(��D��`n���~�����?�^F����ƈ^��V�/��`���$T�)��@��fQ���Q�+K;���5����! 	�ߥ���������;�յ���������[j���8�T_s��k#.����0w�/h�h�F�/�\�#D��X�m������.=1w�p>9s��?�w�E��A�;L�&���9�����䰏R�����hZ�k��LW���o)�#��.�!ʖګN<���i��C1"���>7ӌ�@R�`���
u��HE��`A9o�����-�<�a�e�qud��<����+ ȿ��p���`�.�q�6�������>���b,v�;�i��շ�kk���������)����B�L�]]z�E'�c��e�^O�}E鿻���|YS� ������,���������O6&������'��'��'��'��'��'��'��'��'��'��'��'��'��'��'��'��'��'��'��'��'��'������6g?�>�il!��lj|j�cٝ$z��3�YX-�gc'c��/,A��,��%�/�y�n8:!%3���.�����M��n���ǵ����Vd}ûM�+�cI�W�h�.T�Q����vҢ{�([XJ{=pw��ga~�?4z+,HU��f����i?zu�[]d
�%�D��ց	��C�E>�����~���8�U~>����>�%����vC�z��ݙ��9��Cd��ϊ
�߮�	@�����M5O<�Gf#��ܱ���q*rq���Њ�0sQ���M���E�ڲu��7�t�Dݼu��o��7 �o�����*4��)�w�CN�ZtI%Z�L��3�H����y�*/,����/�9&:A]�:�8��RnlWپ}?�B���ժ���^֟*ŲE�R� ��]H:�)8{�(V��+�\z�ɓ��,�}%p/ͥJ´�&,�t8e�Nܬ��8��r_��Ƶ-�վ�Wv�7!o���`��m�K3�ٵ)x��>4K�[���:��8����k��x֐j���_Q|�O{�̵�ɨ�so��uh�֥[�ΥG��Em^fl.��wzQ�w=���-6�#S�#�5��%=���1��%��6g{�������z	[B1�V$e-��R�bB�ܺ�h�;����� ��I��ME��,-d���_���r�ͭ��ˊS�+%�8�{�g��.�,���q�H�	 !��mz"2	-��ɢ��k�����-MQ]��Y^n��`R2gȧ�
yӥ$�Տ;g��v�}}C1�a'���{��uq�JZRG���<����\3v]K��S��5�����:͝�󖹍���b�s�]��yG����$( 񪇧)�U�7��Z<(A�S.˘�=�xRb��� 
(�*��Ȕ�6Lќ�n�Ù֪A�I�h���HJ���^�l�?7&}d��G��pe���6��6�{�����mZ�ȟ��p+/�8ٖ=�dTԶ\dn��z�t<9B��`�1#�;z��������.0%@�D���`��*;��L��M����j��7M)�m����|����8N,%ҋ��R+*K�� ��H�\4�� �t- ��"�t�H
���.�\י��̙3sf�������?|��-ޞ],i5���qa_���t/�|�V|D�:8!�[Vp��\Pm�҉L�{v��G�E��]2�s�S?�!��9$���^}����u��[�6E��;mR��w$>�i��m%��d���͡'����#d�6G/�-�x޻�XU.�t��!撲���xR��(o�E	��~sY(y
iC����B��îYo�>���p�� �C��"o���||q�����Xg�y�K%ԣ��FF���>�ݮ��_(���n��nkZ����A�Y�-���H�4�\v��j�TO"�oɝ8~�x:/Yj��0�}�U�ȩ�Q��vd6�Uckq�w�f�Px�m��K�p�-dߣӼ��h�b�3,���}�(��|{7�����x�pw�J�R��K�}-�v�[�ۡ��1C�cH�H�򒆬�IB���#�{��c9=T`� ztZZ��	����<0���U���N��-B��ɬj�A� �mj� Ϥ$�����c��o�0�? 20j��t�N\S~[��Ll�:�X�fq�:�?��hG}V��ֲ�k���K�8� I��b��7,�Z��+�О���9��I��+ɦ��%gu�fGU�����/f�{u�;� nʟj�p���k,�G��)�B%È��o�*�6R��2��G��./��5����f���N�g��V�4�<!�������ʒk�~�6��6�6���T�GMw��NhI�s��jܭ��F�ɵ:8���ze�6���S�h9����̛F4�+l��+�8���O�+���<����Mg�W��g�+��B�Z
�#ճ�� 2�%�/r1��i�m�ɾ�s�\����5m�{�� �����VW�n%�/ٴ���6K�����a��'�vd�![BS.6돡�
�2��?V��)�����)����1C�~Sc��>��Г_��{��s dm|�vsv�Y[�F_���GG� 5}�q��YA��͇:#�jc�Z�x��92���L�#�s�*�3�nl�lؒC0���|���*�CX�U���fd�(/fU(5+-����OY[�+�K���F>)�у�Za�
���BB!J�p���?1"į�[,´�=an����)c����H^z��כ�q
h�,c]*#R5�0�?D0���$)i��@�J����庵�?����dV���m.8��w�E.6��	�Mbz>�o�O&&$�I�/\�p�=��b�nVHO���;w����U��3�w�ԍ�?�.�$��r� x�Yer����.nA+o9Zv�䎵}�sP�&f���P�y�,S��Ó��}��į�2p�+Q*���s��8l�LK�f�rW8� ����s7�1����l�<������"a<c���E̻g$�a��JS����������$�s��w������g1�Ü��$���P
���o���h|i9���Or�+L��n������UP		!�x�O�;=� D�=&R�_6(���o�O9�c)�x�@�ڂ�З�����<H'��_N��-�-�u���'�[������u����/�Z*��$�M�dEH�CM��><G=�M�����ܝ��@<3ۋ�j�͟�2{#��Z:L s[jP�L$t;�O���~��m�1�k)wU
�R����1_����f~^S��矈d�e��,M�-��j=|����s����S�G�W��K6.�n��Hz��U�Py2R4Fl�@��ݐ衽W�D�i���_��./�7�$JF��Oq(C��"���5W��÷�5�.�U�+"'fB>?_��<��~1"-��$���f���荩3��rϡ��J/�������k�!� ����s�6&���{�˝�'�N��_��(w��<pS{4˪�ê�݌�cyΖi������������r^����Xd�d2�o�H���r��T��lK��!�B�wBJ=>�w��HX�I":�nrԢ_<�ִ������;�mq��$��l��^]RJ< �"���?�'2^Hy�9`{��pd_��j[�9��r�̭�C��N�ڵ>y�q�y�����-L�^�O�����$gT���]C����̚b�'�u�Jt&Oߒ�p�x��[��=,���T�`�Fz��*S��u�_�����;�6h�e��ӱ�51��[�<�aQ���4`�k���S�&35�As1%M}��;Ș7]��]`/q��21KK2��W�Iqf�}���I����H6��K{��K�����~si�(p}�&�Lhݪ����~WE�<��ġ�H��|�{�"͹S�p��v�z ~^:�ꪯ/�{J�|y������rwl�S�NZ���d���lh�{�?!n껊�xo5�q���y+�Z�v� ÝS<�GW/�+�T��R����v��e�R�`-5����9����4��Z=Wp��1���u9-�h�
��ۭ,r�����A!OH x���!$��x��_��MɃ����&�K�b�98n;��G��?]�g��G9���:i�R�������d�[�y����$�(P�c(�jq��7BX�?Oʩ�E��D�f��`'t�t-b�{H^���eU����L	.�}���`
�7�3}U����x0/�e�5�5�N�݄��c����W�Q����,�����������?������������?������������?������������?������������?������������?�����g�����7���vD���&nU��ِZ���˜1�\��'�ui�t&S��f=/,�um���t�c�;�z�"C���#���ϬY3���c�=7�6]�_t��M�P}�|3�����}loa����4��z8K���4��r��j_����L[q���@�R.���eWP�M��|�n��Ē��5�N�Zn�,��=|%��R�ko�zȾ�vT���"��zT�<�'/G�O:�]��M����|e��*Y02!�Q�Fdď��R=T��eb��;���+�_.�+�]I����+N��ɘ��%A�%���Vd�OC
�b�0ո���	$���
����Y6Os�x�}��c����V�������'�b�����f_O�����"|����k����|���hl�T�$�su6\l�aƲіh$�},4��`	%�Ih�GI�$sLծq���6y)Ra�>�����S�U�x�Pt����tra�߱uJ�]�嶸Sz�����]0hk:�=^v����N�6���
I�ha�џ�b�9�N��,�yz����va��#9�W7ux����g����>ã> �T*�Jf�?�J�X^��'ٱ�������l��9/�3�s��>u��u���;re���elJ�N9��|�(ϖ������e�e�g@��Z���P۶\߬�*��ǩa}�m1T�	��7��:Z�x���7W�WD����_�a�=F�Nu��Lа�K���
��_ƥ�&<5�����Y��#
��T-�Cg�UG������^D	c+홮��}��H�W�ן)��x<Ȑy��${:����¹�Y�I��*�m��Hj�GzQ�������~���oGP�BOV��.o��#3t�j�ԟY/��>���L���u�%	�ÞG�rĄ �]�P�."���W�Ջ2��KH隉�g��(�6��p��IK�SB��X��楴0�4s���In7w���wd�@�uŨA)᧳`<}����X�C���G�N�'L�tམ��>L�t�l�S��f���˄�6�.��CJ�Ս�~7���Z��p�7�Jg��H���az݊.�r{���ع��(l�c�xW�ן���<5�/|>��\.��ˠ��>�c(L�8�Q���[
�J(b^o�n��A�?��6�Fzj���g��?�����CANG�^B`gH�C�I�c��Rϩ��8�E�1��݅�E��\$&����t�g��22��S�!��R{�എ�n�+o�nf�0! 3�U�j�#��J��G�̄��f��P�_�ҍ�5�Ld�+DN�1��h�-�L?�c9J԰��T�a��+���c�t��c����;��W�RC0	]n{�lVJv�Z��"�ET~
��2���j�jL��ϗgw8�v�����<��&P�������5X�s��2ѹ��N7>3��h���ȼ��6�(�����n>�G�+�Ifͯ���5W��Y�^V��e�a�II'O����_Ew����^�L������w���/g_���t���4�*�x2W��uJ��7iR'f(u}����p�垽5�B��|����s��]#k�!�#��o+|),�Σ��y����)����.�Jҵ��w�,�	d��sb�����Ep�_����&Z�OZ�?{�a�%�c%%��e��{om�n�g����,�U������5m����������EE[�f'F���j����7�iU�(l<4��a�c��~��ٜ9O�Xt���/˱oi> �-5?��y��}����a� ]f�{���vof�5��/�i�����F�o���ŧ���UP�'�Z�b��������lի�Jk%vlv�]���p�)զ��~��`�	�u��-	?���t��|�����o�ui՞��3_C�����g�y=��k�ɳ�K�f�3b�x�)�DƔ8��'[<{�2{rb��żͩ+3xo1Yl]�ga�ߘ���O���_��ݘS�����d߶��OW~���D������B=O?�߿�r���w�~�ǫ�m��%�ڵC������gO��Vu����Y\sk�D�5��Th��%qG3%~=d�Z���k��Il���n�Lr�	�����-��-{~]��~��S����3L�PY{��̭��m�O��_�Yz�������͸�����m�?��d[���>Sx����[�2��63�Q_���]q������sm��{֋�l��Ky��;��� w�ˮ�G~}��]&q�\��gN�&�>���o�us-���ֲ��av���Y�|��?z�'��F��Bտ��l~-��a�D���yb6�_N�Nv5��`�M��[�C<�e't~
���;u��2�� ��m/3׮~uT0������µl����xWĖ��a��YuM#����m�����cֳ�z������8�>�_�x��}��'�J�����Ƕ����܉��_bޚ���n�s�&>M��|�����Lv�-�l��`�
���+1�z�5��r�ߴ�y��g�mLC����	�.�R����}�ߔ;:��,�̓+0���� �7j��~��L��~��eN��k��;��u-@'nډW�T�����ww��O��_��8�7�ВsK���M�:.:�uq�:������s����&]���Q�L��5���]wy��.��3�H��������o$_���@\�º ����ۜZ&"��7���w+l�^���mwy�E���_|tFx��0L�r��{{�P���Q@@��EZ He;���50631C��kbjl6��� y�or����(к?]�E�N(ȊJ��Q�DĺY}�Bk��#������A;O�R��!��ж�C������"+:��M2�4����2/_!�4uɩE%��\�U������Eəə��Hl#$���BJ>l�'te��&N�ו\�/U2��:(-1�$1/%_O��,ȦJ,��a����
�D�ZSY�[T�Ex;>���S+��KK`+�A[��R�6!y	���䋌�R��ĢDd���aBq���UF(�2����Hq�1���Q\eLEW��
��AKá�i�i��.S2�2SJ3�� �:@77�(h.�G�d�-�p��
z������Ԅ�Z��)��j��n�ݢ1�Z�����e���!���! B-G�E�bS�Uu>������A8&^5�j.2W6Jnn�pYWԍ�4
�j�P��KL������ą<�q(!��
c�B�M-�O�8 ���A� ����QC=j`�(��%���#�l�r��
y����C�t+a��Q0
F�(�`��Q0
F�(�`��Q0
F�(�`��Q0
F�(�  ��v �  