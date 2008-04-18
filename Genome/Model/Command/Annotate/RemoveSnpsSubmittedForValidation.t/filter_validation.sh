cat Ley_Siteman_AML_variant_validation.10mar2008a.csv | awk '{FS="\t";if($42=="G"||$42=="WT"||$42=="S"||$42=="LOH"||$42=="O") print $2","$4","$5","$6;}' > list
grep -v -f list $1 > $1.out
# added redirecing the grep output
