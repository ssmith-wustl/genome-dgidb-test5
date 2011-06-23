#get command line arguments
clinical_data = as.character(commandArgs()[4]);
mutation_matrix = as.character(commandArgs()[5]);
output_file = as.character(commandArgs()[6]);
method = as.character(commandArgs()[7]);


# FUNCTION finds the correlation between two variables
cor2=function(ty,tx,method)
{

id=intersect(!is.na(ty),!is.na(tx));
ty=ty[id];
tx=tx[id];

if(method=="cor")
{
tst=cor.test(tx,ty);
s=tst$est;
p=tst$p.value;
}

if(method=="wilcox")  #x must be (0,1) mutation data
{
tst=wilcox.test(x=ty[tx==0],y=ty[tx>=1])
s=tst$stat
p=tst$p.value
}

if(method=="chisq")
{
tst=chisq.test(tx,ty);
s=tst$stat;
p=tst$p.value;
}

if(method=="fisher")
{
tst=fisher.test(tx,ty)
s=tst$p.value
p=tst$p.value
}

if(method=="anova")
{
tst=summary(aov(ty~tx,as.data.frame(cbind(tx,ty))))
s=tst[[1]]$F[1]
p=tst[[1]]$Pr[1]
}

tt=c(p,s);
tt;
}
# END cor2

# FUNCTION runs correlation test on matrixes of data
cor2test =function(y,x=NULL,method="cor",cutoff=1,sep="\t",outf=NULL)
{

if (!is.null(x))
{

if (length(x)==1) {read.table(x,header=T,sep=sep)->x;}
if (length(y)==1) {read.table(y,header=T,sep=sep)->y;}
colnames(y)[1]="id";
colnames(x)[1]="id";
tt=character(0);
for (vi in colnames(x)[-1])
{
for (vj in colnames(y)[-1])
{
tx=x[,c("id",vi)];
tx=tx[!is.na(tx[,vi]),];
tx=tx[!duplicated(tx[,"id"]),];
ty=y[,c("id",vj)];
ty=ty[!is.na(ty[,vj]),];
ty=ty[!duplicated(ty[,"id"]),];
xy=merge(tx,ty,by.x="id",by.y="id");
tx=xy[,2];
ty=xy[,3];
n=length(xy[,"id"]);
rst=try(cor2(ty,tx,method));
if (class(rst)=="try-error") {p=NA;s=NA;} else {p=rst[1];s=rst[2];}
t=c(vi,vj,method,n,s,p)

tt=rbind(tt,t);
} #end vj
} #end vi

rownames(tt)=NULL;
colnames(tt)=c("x","y","method","n","s","p");
tt=as.data.frame(tt);
tt[,"s"]=as.character(tt[,"s"]);
tt[,"s"]=as.numeric(tt[,"s"]);
tt[,"p"]=as.character(tt[,"p"]);
tt[,"p"]=as.numeric(tt[,"p"]);
fdr=p.adjust(tt[,"p"],method="fdr");
bon=p.adjust(tt[,"p"],method="bon");
tt=cbind(tt,fdr,bon);
tt=tt[order(tt[,"p"]),];
}

if (is.null(x))
{

if (length(y)==1) {read.table(y,header=T,sep=sep)->y;}
x=y;
nxy=ncol(y)-1;
colnames(y)[1]="id";
colnames(x)[1]="id"
tt=character(0);
for (i in c(1:(nxy-1)))
{
for (j in c((i+1):nxy))
{

vi=colnames(x)[-1][i];
vj=colnames(y)[-1][j];

tx=x[,c("id",vi)];
tx=tx[!is.na(tx[,vi]),];
tx=tx[!duplicated(tx[,"id"]),]
ty=y[,c("id",vj)];
ty=ty[!is.na(ty[,vj]),];
ty=ty[!duplicated(ty[,"id"]),];
xy=merge(tx,ty,by.x="id",by.y="id");
tx=xy[,2];
ty=xy[,3];
n=length(xy[,"id"]);
rst=try(cor2(ty,tx,method));
if (class(rst)=="try-error") {p=NA;s=NA;} else {p=rst[1];s=rst[2];}
t=c(vi,vj,method,n,s,p);
tt=rbind(tt,t);
} #end vj
} #end vi

rownames(tt)=NULL;
colnames(tt)=c("x","y","method","n","s","p");
tt=as.data.frame(tt);
tt[,"s"]=as.character(tt[,"s"]);
tt[,"s"]=as.numeric(tt[,"s"]);
tt[,"p"]=as.character(tt[,"p"]);
tt[,"p"]=as.numeric(tt[,"p"]);
fdr=p.adjust(tt[,"p"],method="fdr");
bon=p.adjust(tt[,"p"],method="bon");
tt=cbind(tt,fdr,bon);
tt=tt[order(tt[,"p"]),];
}


if (!is.null(outf))
{
colnames(tt)=c("x","y","method","n","s","p","fdr","bon");
tt=tt[order(tt[,"x"]),];
tt=tt[order(tt[,"p"]),];
write.table(tt,file=outf,quote=FALSE,row.names=FALSE,sep=",");}
invisible(tt);
}
#END cor2test

#run correlation test using function
cor2test(y = clinical_data, x = mutation_matrix, method = method, outf = output_file);
