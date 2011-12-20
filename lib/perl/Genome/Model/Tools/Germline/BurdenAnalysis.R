############# funtions ############

############ QQ plot #################################

myqqplot=function(ps,ylm=NULL)
{
as.data.frame(ps)->ps
for (pname in colnames(ps))
{
pi=ps[,pname];pi=pi[!is.na(pi)];pi=-log10(pi);pi=sort(pi)
p0=c(1:length(pi))/length(pi);p0=-log10(p0);p0=sort(p0)
pp=cbind(p0,pi)
matplot(p0,pp,main=pname,ylab="",xlab="",ylim=ylm,type="l",lty=1,lwd=2)
#legend(x="bottomright",legend=colnames(x),col=co,lty=1,lwd=2,box.lty=0)
}
}

############## ROC ############################
myroc=function(tt,ps,effcol,fpr=NULL)
{
if (is.null(fpr)) fpr=c((1:9)/100,(1:10)/10)
ttp=as.data.frame(fpr)
for (gi in ps)
{
p=tt[,gi]
p[is.na(p)]=1
p0=p[tt[,effcol]==0]
qk=quantile(p0,fpr)
pi=p[tt[,effcol]!=0]
ni=length(pi)
powi=NULL;for (j in 1:nrow(ttp)) powi=c(powi,signif(sum(pi<=qk[j])/ni,5))
ttp=cbind(ttp,powi)
}
colnames(ttp)=c("FPR",ps)
ttp
}

####### ROC PLOT ################

mymatplot=function(x,y=NULL,xlm=c(0,1),ylm=c(0,1),lgs=NULL,tit="",cos=c("black","blue","red","green","brown","pink","purple"))
{
if (is.null(y)) {y=x[,-1];colnames(y)=colnames(x)[-1];x=x[,1]}
if (is.null(lgs)) lgs=colnames(y)
matplot(x,y,xlim=xlm,ylim=ylm,ylab="TPR",xlab="FPR",main=tit,cex.main=2,
type="l",lwd=2,lty=1,pch="*",cex.lab=1.5,cex.axis=1.5,col=cos)
legend(x="bottomright",legend=lgs,lwd=2,lty=1,col=cos,cex=1.5,bty="n")
}

####################### get sum weights Madson & Browning ################################

sumweights=function (x,ctrid=NULL)
{
#x: genotyps 0,1,2; 1,2 are rare/minor
#ctrid: controal id

xii=x
if (is.null(ctrid)) ctrid=c(1:nrow(xii))
cid=rep(F,nrow(xii))
cid[ctrid]=T

###rare allele total counts
x0=rowSums((xii==2),na.rm=T)
x1=rowSums((xii==1),na.rm=T)
x2=x0+x1
xt=2*x0+x1
###Collaping
z0=as.numeric(x0>0)
z1=as.numeric(x1>0)
z2=as.numeric(x2>0)

###weighted sum
sum(xt[cid],na.rm=T)-> xc1
sum(xt,na.rm=T)-xc1 -> xc2
sum(z2[cid],na.rm=T)-> nc1
sum(z2,na.rm=T)-nc1 -> nc2

cid[is.na(cid)]=F
niu=sum(cid) # control number
miu=colSums(xii[cid,],na.rm=T) # rare var number per snp in controls
qi=(miu+1)/(2*niu+2)
wi=sqrt(nrow(xii)*qi*(1-qi))
#Iij=xii*NA;Iij[xii==0]=1;Iij[xii==1]=0;Iij[xii==2]=0
#rowSums(t(t(Iij)/wi),na.rm=T)->w0
wi=1/wi
tt=list(wi=wi,xc1=xc1,xc2=xc2,nc1=nc1,nc2=nc2)
tt
}


##########################################
g.simu.unif=function(n,m,f,name)
{
g.prob=c((1-f)^2,2*f*(1-f),f^2)
sample(x=c(0,1,2),size=m*n,replace=T,prob=g.prob)->temp
matrix(temp,n,m)->temp
colnames(temp)=paste(name,1:m,sep="")
temp
}

##########################################
g.simu.varf=function(n,m,f,fsd,name)
{
fs=abs(rnorm(m,f,fsd))
tt=NULL
for (fi in fs)
{
g.prob=c((1-fi)^2,2*fi*(1-fi),fi^2)
sample(x=c(0,1,2),size=n,replace=T,prob=g.prob)->temp
tt=cbind(tt,temp)
}
colnames(tt)=paste(name,1:m,sep="")
tt
}


### genotype(x) simulation ###
genotype.simu=function(n.pool,n.mk,r.up,r.dw,f.ra,f.sd=0,vtype="number")
{
N=n.pool

if (vtype=="percent")
{
x.up=NULL; M=as.integer(r.up*n.mk+0.5); if (M>0) g.simu(n=N,m=M,f=f.ra,name="up")->x.up
x.dw=NULL; M=as.integer(r.dw*n.mk+0.5); if (M>0) g.simu(n=N,m=M,f=f.ra,name="dw")->x.dw
x.md=NULL; M=n.mk-as.integer(r.up*n.mk+0.5)-as.integer(r.dw*n.mk+0.5)
if (M>0) g.simu(n=N,m=M,f=f.ra,name="md")->x.md
}

if (vtype=="number")
{
x.up=NULL; M=r.up; if (M>0) g.simu.varf(n=N,m=M,f=f.ra,fsd=f.sd,name="up")->x.up
x.dw=NULL; M=r.dw; if (M>0) g.simu.varf(n=N,m=M,f=f.ra,fsd=f.sd,name="dw")->x.dw
x.md=NULL; M=n.mk-r.up-r.dw
if (M>0) g.simu.varf(n=N,m=M,f=f.ra,fsd=f.sd,name="md")->x.md
}

x=cbind(x.up,x.dw,x.md)
rownames(x)=c(1:nrow(x))
x
}

###########################################################
phenotype.simu=function(x,eff.ra,eff.sd,model="additive")
{
if (model=="additive")
{
eff=rnorm(ncol(x),eff.ra,eff.sd)
grep("up",colnames(x))-> col.up
grep("dw",colnames(x))-> col.dw
grep("md",colnames(x))-> col.md
if (length(col.up)>0) eff[col.up]=abs(eff[col.up])
if (length(col.dw)>0) eff[col.dw]=-abs(eff[col.dw])
if (length(col.md)>0) eff[col.md]=0
y=rnorm(nrow(x)) +  colSums(t(x)*eff)
}
y
}

################################################
sampling.simu=function(y0,n.sample,design="RDM")
{
if (design=="RDM")
{
id=sample(1:length(y0),n.sample)
y=y0[id]
grp=NULL
}

if (design=="LR")
{
id=1:length(y0)
n.sample/length(y0)->pct
id[y<=quantile(y,pct/2)] -> Lid
id[y>=quantile(y,(1-pct/2))] -> Rid
id=c(Lid,Rid)
y=y0[id]
grp=c(rep("L",length(Lid)),rep("R",length(Rid)))
}

if (design=="LCR")
{
id=1:length(y0)
n.sample/length(y0)->pct
id[y<=quantile(y,pct/3)] -> Lid
id[y>=quantile(y,(1-pct/3))] -> Rid
id[y>=quantile(y,(0.5-pct/3/2)) & y<=quantile(y,(0.5+pct/3/2))] -> Cid
id=c(Lid,Cid,Rid)
y=y0[id]
grp=c(rep("L",length(Lid)),rep("C",length(Cid)),rep("R",length(Rid)))
}

if (design=="LC")
{
id=1:length(y0)
n.sample/length(y0)->pct
id[y<=quantile(y,pct/2)] -> Lid
id[y>=quantile(y,(0.5-pct/2/2)) & y<=quantile(y,(0.5+pct/2/2))] -> Cid
id=c(Lid,Cid)
y=y0[id]
grp=c(rep("L",length(Lid)),rep("C",length(Cid)))
}

if (design=="CR")
{
id=1:length(y0)
n.sample/length(y0)->pct
id[y>=quantile(y,(1-pct/2))] -> Rid
id[y>=quantile(y,(0.5-pct/2/2)) & y<=quantile(y,(0.5+pct/2/2))] -> Cid
id=c(Cid,Rid)
y=y0[id]
grp=c(rep("C",length(Cid)),rep("R",length(Rid)))
}

samp=list(y=y,id=id,grp=grp,design=design)
samp
}

#############################################
collapse.analysis=function(z)
{
#################### prepare data 
#z=samp

z$x=z$x[,sd(z$x,na.rm=T)>0]

design=z$design
id=z$id
grp=z$grp
y=z$y
x=z$x

#x[x>1]=1

######################### single variant analysis 
p1=NULL; r1=NULL
xnames=colnames(x)
for (xi in xnames)

{

x[,xi]=as.numeric(as.character(x[,xi]))

rtemp=NA
fit=try(cor(x[,xi],y,use="pairwise.complete.obs"))
if (class(fit)!="try-error") rtemp=fit
r1=c(r1,rtemp)

ptemp=NA
fit=try(cor.test(x[,xi],y,alternative="less"))
if (class(fit)!="try-error") ptemp=fit$p.value
p1=c(p1,ptemp)
}

x=t(x)

################## wieghting, collapsing, sum score ###########################

############################################################### for any designs

w=1;colSums(x*w,na.rm=T)->xi; x00=xi # CAST
xi[xi>1]=1;x0=xi #CMC
#w=as.numeric(r1<0);colSums(x*w,na.rm=T)->xi;xi[xi>1]=1;xdw=xi 
#w=as.numeric(r1>0);colSums(x*w,na.rm=T)->xi;xi[xi>1]=1;xup=xi
#w=p1;colSums(x*w,na.rm=T)->xp # PWST non-rescaled
w=p1-0.5; colSums(x*w,na.rm=T)->xp1 # PWST rescaled uniform
#vSelect(x=t(x),y=y,w=w,method="hoffmann")->stepup.pw
w=p1; w[p1<0.05 & r1<0]=-1; w[w>0]=1; colSums(x*w,na.rm=T)->xp2  # Han & Pan P<0.05 
w=log(p1/(1-p1));colSums(x*w,na.rm=T)->xplog  # PWST rlogit escaled normal
w=-log(2*p1)*as.numeric(r1<0);colSums(x*w,na.rm=T)->xdwlog   #SPWST  -log(p)
w=-log(2*(1-p1))*as.numeric(r1>0);colSums(x*w,na.rm=T)->xuplog
#w=r1; w[w<0]=-1; w[w>0]=1; colSums(x*w,na.rm=T)->wbd  # weighted only by direction + or - 
#vSelect(x=t(x),y=y,w=w,method="hoffmann")->stepup

#w=p1; w[w<0.1]=-1; w[w>0.9]=1; w[abs(w)!=1]=0; colSums(x*w,na.rm=T)->c3  # 3 classes + - 0 
#vSelect(x=t(x),y=y,w=w,method="hoffmann")->stepup.c3

xc=cbind(x00,x0,xp1,xp2,xplog,xdwlog,xuplog)

ms=list(
CAST=list(var="x00",test="cor",alt="two.sided",id=!is.na(y)),
CMC=list(var="x0",test="cor",alt="two.sided",id=!is.na(y)), 
#xdw=list(var="xdw",test="cor",alt="two.sided",id=!is.na(y)),
#xup=list(var="xup",test="cor",alt="two.sided",id=!is.na(y)),
PWST1=list(var="xp1",test="cor",alt="two.sided",id=!is.na(y)), 
aSum=list(var="xp2",test="cor",alt="two.sided",id=!is.na(y)), 
#PWST0=list(var="xp",test="cor",alt="two.sided",id=!is.na(y)),
xdwlog=list(var="xdwlog",test="cor",alt="two.sided",id=!is.na(y)),
xuplog=list(var="xuplog",test="cor",alt="two.sided",id=!is.na(y)),
PWST2=list(var="xplog",test="cor",alt="two.sided",id=!is.na(y))
#WBD=list(var="wbd",test="cor",alt="two.sided",id=!is.na(y))
)

xc1=NULL;ms1=NULL
#################################################################  different designs
if (design=="RDM")  
{xc1=NULL;ms1=NULL}

if (design %in% c("LR") )
{
w=sumweights(t(x[,grp=="L"]))$wi;colSums(x*w,na.rm=T)->xwR
w=sumweights(t(x[,grp=="R"]))$wi;colSums(x*w,na.rm=T)->xwL
xc1=cbind(xwR,xwL)
ms1=list(
xwR=list(var="xwR",test="cor",alt="two.sided",id=!is.na(grp)), 
xwL=list(var="xwL",test="cor",alt="two.sided",id=!is.na(grp)) 
)
#x0c=list(var="x0",test="fisher",alt="two.sided",id=!is.na(grp)),
#xdwc=list(var="xdw",test="fisher",alt="less",id=!is.na(grp)),
#xupc=list(var="xup",test="fisher",alt="greater",id=!is.na(grp)),
}

if (design=="LCR")
{
w=sumweights(t(x[,grp=="C"]))$wi;colSums(x*w,na.rm=T)->xw
xc1=cbind(xw)
ms1=list(
xwR=list(var="xw",test="cor",alt="two.sided",id=(grp!="L")),
xwL=list(var="xw",test="cor",alt="two.sided",id=(grp!="R"))
)
#x0Rc=list(var="x0",test="fisher",alt="two.sided",id=(grp!="L")),
#x0Lc=list(var="x0",test="fisher",alt="two.sided",id=(grp!="R")),
#xdwc=list(var="xdw",test="fisher",alt="less",id=!is.na(grp)),
#xupc=list(var="xup",test="fisher",alt="greater",id=!is.na(grp)),
} 

ms=c(ms,ms1)
xc=cbind(xc,xc1)

####################################### trait and sum score association
pp=NULL
for (i in names(ms))
{
pi=NA
ms[[i]]$var->vi
if (vi %in% colnames(xc))
{
ms[[i]]$id->ids
ms[[i]]$alt->alti
if (ms[[i]]$test=="cor") fit=try(cor.test(xc[ids,vi],y[ids],alternative=alti))
if (ms[[i]]$test=="fisher") fit=try(fisher.test(table(xc[ids,vi],grp[ids]),alternative=alti))
if (class(fit)!="try-error") pi=fit$p.value
}
pp=c(pp,pi)
}

names(pp)=names(ms)

#pmin=min(pp["xdw"],pp["xup"],na.rm=T);names(pmin)="pmin"
pminlog=min(pp["xdwlog"],pp["xuplog"],na.rm=T);names(pminlog)="pminlog"
#StepUp=-stepup$chi;names(StepUp)="StepUp"
#StepUp.PW=-stepup.pw$chi;names(StepUp.PW)="StepUp.PW"
#StepUp.C3=-stepup.c3$chi;names(StepUp.C3)="StepUp.C3"

pp=c(pp,pminlog) #StepUp,StepUp.PW) 

rst=list(variants=xnames,p1=p1,r1=r1,p=pp)
}

################################

collapse.test=function(z,permu=0)
{
collapse.analysis(z)->rst
if (permu>0) 
{
p=rst$p
#p[is.na(p)]=1
pp=p*0
for (i in 1:permu)
{
id=sample(c(1:length(z$id)))
z$id=z$id[id]
if (!is.null(z$y)) z$y=z$y[id]
if (!is.null(z$grp)) z$grp=z$grp[id]
collapse.analysis(z)$p->pi
pi[is.na(pi)]=p[is.na(pi)]+1
pp=pp+as.integer(pi<=p)
}
p=pp/permu
rst$pp=p
}
rst
}

######################## variable selection

vSelect=function(x,y,w=NULL,method="hoffmann")
{
x=as.data.frame(x)

if (ncol(x)==0) z=list(id=0,chi=NA)
if (ncol(x)==1) z=list(id=1,chi=NA)
if (ncol(x)>1) 
{
if (method=="hoffmann") #step-up,by Hoffmann,PLOSone,2010,5(11)p3
{

###
#z=samp
#z$x=z$x[,sd(z$x,na.rm=T)>0]
#x=z$x
#y=z$y
#x=as.data.frame(x)
if (is.null(w))
{
w=as.numeric(cor(x,y))
w[w>0]=1
w[w<0]=-1
}
###

xkm=colMeans(x,na.rm=T)
ym=mean(y,na.rm=T)
t((t(x)-xkm)*w)*(y-ym)->u
ks0=1:ncol(x)
kid=NULL
chi00=0
tt=NULL
while(length(kid)<length(ks0))  #----------------
{

if (is.null(kid)) ks=ks0
if (!is.null(kid)) ks=ks0[-kid]
chi0=0
ki=0
for (k in ks)
{ 
if (sd(u[,k])>0)
{
c(kid,k)->ksi
sum(u[,ksi],na.rm=T)^2 / sum(rowSums(cbind(u[,ksi],0),na.rm=T)^2,na.rm=T) -> chik
if (chik>chi0) {chi0=chik;ki=k}
}
}

if (chi0>=chi00) {kid=c(kid,ki);chi00=chi0}
#kid=c(kid,ki)
#tt=c(tt,chi0)
#print(kid)
#print(chi0)
if (chi0<chi00) break

} # while -------------------------------------------

ks0*0->sele
sele[kid]=1
if (chi00==0) chi00=NA
z=list(id=sele,chi=chi00)

} # hoffman

} # ncol>1

z

}
