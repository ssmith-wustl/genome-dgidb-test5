####### SMG Test Library #############################

smg_test=function(in.file,test.file)
{
  source("/gscuser/qzhang/gstat/mut_class_test/lib.R");

  read.table(in.file,header=T,sep="\t")->mut
  mut$BMR=as.numeric(as.character(mut$BMR))

  #select the rows with BMR data
  mut=mut[mut$BMR>0 & !is.na(mut$BMR) & mut$Bases>0,]
  tt=NULL
  for (gene in unique(as.character(mut$Gene)))
  {
    mutgi=mut[mut$Gene==gene,]
    mut_class_test(mutgi[,3:5],hmax=25,bin=0.001)->z
    tt=rbind(tt,cbind(mutgi,z$x[,-(1:3)]))
  }
  write.table(tt,file=test.file,quote=FALSE,row.names=F,sep="\t")
}

smg_fdr=function(in.file,fdr.file)
{
  read.table(in.file,header=T,sep="\t")->x
  x=unique(x)

  #Calculate FDR measure and write FDR output
  p.adjust(x[,2],method="BH")->fdr.fisher
  p.adjust(x[,3],method="BH")->fdr.lr
  p.adjust(x[,4],method="BH")->fdr.convol
  x=cbind(x,fdr.fisher,fdr.lr,fdr.convol)
  write.table(x,file=fdr.file,sep="\t",quote=FALSE,row.names=F)
}

######################################################
