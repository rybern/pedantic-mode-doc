DIR=`pwd`

for file in `ls *.stan`; do
  cd ~/documents/stan/stanc3
  cp $DIR/$file $file
  ./run --warn-pedantic $file 2> $DIR/$file.warnings
  echo $file "->" $file.warnings
done
