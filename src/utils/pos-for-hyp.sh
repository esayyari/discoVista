#!/bin/bash

echo "USAGE: [PATH] [annotation] [names] [OUTDIR] [outgroup]"

if [ "$#" -lt "4" ]; then
	echo "USAGE: [PATH] [annotation] [names] [OUTDIR] [outgroup]"
	echo "Number of inputs should be at least 4 not $#"
	exit 1
fi
name=main
pth=$1



species=$pth/estimated_species_tree.tree
genes=$pth/estimated_gene_trees.tree
annot=$2
names=$3
out=$4
name="main"
if [ ! -s "$genes" ]; then
	echo "your gene trees file does not exist. Please check your gene tree file"
	exit 1
fi
if [ ! -s "$species" ]; then
	echo "your species tree file does not exist. Please check your species tree file"
	exit 1
fi

if [ ! -s "$annot" ]; then
	echo "your annotation file does not exist. Please check your annotation file."
	exit 1
fi


if [ "$#" -ne "5" ]; then
	
	outgroup=""
else
	outgroup=$5
	echo "outgroup is $outgroup"
fi

d=$(dirname $species)

mkdir -p $out || true
cp $species $out/
cp $genes $out/
cp $annot $out/
cp $names $out/

cd $out/

species=$(basename $species)
genes=$(basename $genes)
annot=$(basename $annot)
names=$(basename $names)


echo "Code	Hypo" > $annot.with.header.txt
cat $annot >> $annot.with.header.txt

ant=$(find $annot.with.header.txt)

python $WS_HOME/DiscoVista/src/utils//check-anot-if-mono.py $species $annot
[ $? -eq 0 ] || exit $?
python $WS_HOME/DiscoVista/src/utils/spit-hypo-trees.py $species  $ant contract
[ $? -eq 0 ] || exit $?

d=`pwd`;

cp $species-hypo.tre $d/$name-hypo.tre


astral=$WS_HOME/DiscoVista/bin/astral.5.6.1.jar
java -Xmx8000m -jar $astral -i $genes -q $d/$name-hypo.tre -t 16 -o  $d/$name-uncollapsed.tre > $d/astral-job.log 2>&1
[ $? -eq 0 ] || exit $?

sed -i "s/)N\([0-9][0-9]*\)'/)'N\1/g" $d/$name-uncollapsed.tre


python $WS_HOME/DiscoVista/src/utils/spit-hypo-trees.py $d/$name-uncollapsed.tre $ant collapse
[ $? -eq 0 ] || exit $?
cp $d/$name-uncollapsed.tre-collapsed.tre $d/$name.tre

sed -i  "s/)'N\([0-9][0-9]*\)[^']*'/)N\1/g" $d/$name.tre




printf "$WS_HOME/DiscoVista/src/utils/display.py $d/$name.tre\n"

if [ "$outgroup" != "" ]; then
	$WS_HOME/DiscoVista/src/utils/display.py $d/$name.tre $outgroup
	[ $? -eq 0 ] || exit $?
else
	$WS_HOME/DiscoVista/src/utils/display.py $d/$name.tre
	[ $? -eq 0 ] || exit $?
fi


printf  "python $WS_HOME/DiscoVista/src/utils/map_names.py $names $annot $d/freqQuad.csv $d/freqQuadCorrected.csv $d/$name.tre.out\n"

python $WS_HOME/DiscoVista/src/utils/map_names.py $names $annot $d/freqQuad.csv $d/freqQuadCorrected.csv $d/$name.tre.out
[ $? -eq 0 ] || exit $?
cd $d

Rscript --vanilla freqQuadVisualization.R
$WS_HOME/DiscoVista/src/R/plotTree.R $d/$name.tre.out
