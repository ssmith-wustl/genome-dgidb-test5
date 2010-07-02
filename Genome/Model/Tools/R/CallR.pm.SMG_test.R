#######SMG Test Library###############################

smg_test=function(in.file,test.file,fdr.file)
{
source("/gscuser/qzhang/gstat/stat.lib");

#in.file="/gscuser/qzhang/gstat/example_data/wu_ov94_capture_bmr.lis_genes.csv"
#out.file=paste(in.file,'.smgtest.csv',sep='');

read.table(in.file,header=T,sep="\t")->mut
mut$BMR=as.numeric(as.character(mut$BMR))
#select the rows with BMR data
mut=mut[mut$BMR>0 & !is.na(mut$BMR) & mut$Bases>0,]
tt=NULL
for (gene in unique(as.character(mut$Gene)))
{
mutgi=mut[mut$Gene==gene,]
mut_class_test(mutgi[,3:5])->z
tt=rbind(tt,cbind(mutgi,z$x[,-(1:3)]))
}
write.table(tt,file=test.file,quote=FALSE,row.names=F,sep="\t")

#Calculate FDR measure and write FDR output
x=tt[,c(1,11:13)]
x=unique(x)
p.adjust(x[,2],method="BH")->fdr.fisher
p.adjust(x[,3],method="BH")->fdr.lr
p.adjust(x[,4],method="BH")->fdr.convol
x=cbind(x,fdr.fisher,fdr.lr,fdr.convol)
write.table(x,file=fdr.file,sep="\t",quote=FALSE,row.names=F)

}
######################################################
