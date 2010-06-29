#######SMG Test Library###############################

smg_test=function(in.file,out.file)
{
source("/gscuser/qzhang/gstat/stat.lib");

#in.file="/gscuser/qzhang/gstat/example_data/wu_ov94_capture_bmr.lis_genes.csv"
#out.file=paste(in.file,'.smgtest.csv',sep='');

read.table(in.file,header=T,sep="\t")->mut
mut$BMR=as.numeric(as.character(mut$BMR))
#select the rows with BMR data
mut=mut[mut$BMR>0 & !is.na(mut$BMR),]
tt=NULL
for (gene in unique(as.character(mut$Gene)))
{
mutgi=mut[mut$Gene==gene,]
mut_class_test(mutgi[,3:5])->z
tt=rbind(tt,cbind(mutgi,z$x[,-(1:3)]))
}
write.csv(tt,file=out.file,quote=F,row.names=F)
}
######################################################
