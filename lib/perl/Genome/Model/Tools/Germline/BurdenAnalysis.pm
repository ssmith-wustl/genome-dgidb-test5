package Genome::Model::Tools::Germline::BurdenAnalysis;

use warnings;
use strict;
use Carp;
use Genome;
use IO::File;
use POSIX qw( WIFEXITED );

class Genome::Model::Tools::Germline::BurdenAnalysis {
  is => 'Genome::Model::Tools::Music::Base',
  has_input => [
    mutation_file => { is => 'Text', doc => "Mutation Matrix" },
    phenotype_file => { is => 'Text', doc => "Phenotype File" },
    marker_file => { is => 'Text', doc => "List of mutations in MAF format" },
    project_name => { is => 'Text', doc => "The name of the project" },
#    base_R_commands => { is => 'Text', doc => "The base R command library", default => '/gsc/scripts/opt/genome/current/pipeline/lib/perl/Genome/Model/Tools/Germline/BurdenAnalysis.R' },
    base_R_commands => { is => 'Text', doc => "The base R command library", default => '~/git-dir/Genome/Model/Tools/Germline/BurdenAnalysis.R' },
    output_file => { is => 'Text', doc => "Results of the Burden Analysis" },
  ],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Run a burden analysis on germline (PhenotypeCorrelation) data"                 
}

sub help_synopsis {
    return <<EOS
Run a burden analysis on germline (PhenotypeCorrelation) data
EXAMPLE:	gmt germline burden-analysis --help
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
  return (
<<"EOS"

/gscuser/qzhang/ASMS/asms111003complete/
/gscuser/qzhang/ASMS/option.R
/gscuser/qzhang/ASMS/rarelib20111003.R
/gscuser/qzhang/ASMS/bsub.R
/gscuser/qzhang/ASMS/sum.R
/gscuser/qzhang/ASMS/asms111003complete_burden.csv
/gscuser/qzhang/ASMS/asms111003complete_indv.csv
/gscuser/qzhang/ASMS/asms20111003.R


*file set up etc are in option.R
*rarelib2011003.R contains the statistical functions
*bsub.R is a wrapper for submitting to the cluster
*sum.R compiles the output into a single summary table
*asms20111003.R contains the outline of how the data is to be processed for the ASMS project (chooses a method etc)

The output for ASMS is

/gscuser/qzhang/ASMS/asms111003complete/

There is one output file for each clinical attribute and gene.

EOS
    );
}


###############

sub execute {                               # replace with real execution logic.
	my $self = shift;

    my $mutation_file = $self->mutation_file;
    my $phenotype_file = $self->phenotype_file;
    my $marker_file = $self->marker_file;

    my $base_R_commands = $self->base_R_commands;

    my $output_file = $self->output_file;

    my $project_name = $self->project_name;

    my $pheno_fh = new IO::File $phenotype_file,"r";
    my $pheno_header = $pheno_fh->getline;
    close($pheno_fh);
    my @pheno_headers = split(/\t/, $pheno_header);
    my $subject_column_header = $pheno_headers[0];

    #make .R file
    my ($tfh_R_option,$R_path_option) = Genome::Sys->create_temp_file;
    unless($tfh_R_option) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    $R_path_option =~ s/\:/\\\:/g;

    my $temp_path_output = Genome::Sys->create_temp_directory;
    $temp_path_output =~ s/\:/\\\:/g;

    #-------------------------------------------------
    my $R_command_option = <<"_END_OF_R_";
out.dir="$temp_path_output"
if (!file.exists(out.dir)==T) dir.create(out.dir)

############################################### data file names
marker.file="$marker_file"
vid="variant"
function_unit="gene_name"
genotype.file="$mutation_file"
gsubid="$project_name"
phenotype.file="$phenotype_file"
psubid="$subject_column_header"
maf_cutoff=0.01
permun=10000

#-------------------------
############################################## data input & prepare
read.table(marker.file,sep="\t")->m
read.table(genotype.file,header=T,sep="\t")->x
read.table(phenotype.file,header=T,sep="\t")->y
names(m)[c(1,8,15)]=c("variant","gene_name","trv_type")
#gsub("chr","X",m[,vid])->m[,vid] #changed Vasily annotation to our variant names
#gsub("[:]","_",m[,vid])->m[,vid] #changed Vasily annotation to our variant names
#gsub("[/]","_",m[,vid])->m[,vid] #changed Vasily annotation to our variant names

m=m[ !(m\$trv_type \%in\% c("silent","intronic")), ]
gsub(" variant protein","",as.character(m\$gene_name))->m\$gene_name
#coding-synon       intron     missense     nonsense        utr-3        utr-5 #####################Vasily annotation options
#frame_shift_del    frame_shift_ins    in_frame_del    in_frame_ins    missense    nonsense    nonstop    silent    splice_site    splice_site_del    splice_site_ins    -    3_prime_flanking_region    3_prime_untranslated_region    5_prime_flanking_region    5_prime_untranslated_region    intronic    splice_region    #####################WU annotation options

for (i in c(2:ncol(x))) {if (class(x[,i])!="integer")  {x[,i]=as.integer(as.character(x[,i]))} }

dim(x)
x1=x[,-1]
#colSums(is.na(x1))/nrow(x1)<0.01 -> cid
#rowSums(is.na(x1))/ncol(x1)<0.01 -> rid
colSums(is.na(x1))/nrow(x1)==0 -> cid
rowSums(is.na(x1[,cid]))/ncol(x1[,cid])==0 -> rid
x=x[rid,c(TRUE,cid)]
dim(x)
_END_OF_R_
    #-------------------------------------------------

    print $tfh_R_option "$R_command_option\n";

    my $cmd_option = "R --vanilla --slave \< $R_path_option";
    my $return_option = Genome::Sys->shellcmd(
        cmd => "$cmd_option",
    );
    unless($return_option) { 
        $self->error_message("Failed to execute: Returned $return_option");
        die $self->error_message;
    }


    #make .R file
    my ($tfh_R_project,$R_path_project) = Genome::Sys->create_temp_file;
    unless($tfh_R_project) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    $R_path_project =~ s/\:/\\\:/g;

    #-------------------------------------------------
    my $R_command_project = <<"_END_OF_R_";


source("$R_path_option")
source("$base_R_commands")

trait=commandArgs()[3]
gene=commandArgs()[4]

#[688] "bsub 'R --no-save < asms.R diares DYNC2LI1 '"


########################################## functions
# Genotype : MAF
maf=function(x)
{
colSums(x==2,na.rm=T)->aa
colSums(x==1,na.rm=T)->ab
colSums(x==0,na.rm=T)->bb
f=(aa+ab/2)/(aa+ab+bb)
f
}
#########################################

if ( !is.na(gene) & !is.na(trait))
{

####################### select data for analysis
print(gene)
print(trait)
xs=as.character(m[m[,function_unit]==gene,vid])

rst=NULL
if (length(xs)>1)
{

xs=gsub("-",".",xs)
xy=merge(y[,c(psubid,trait)],x[,colnames(x) \%in\% c(gsubid,xs)], by.x=psubid,by.y=gsubid)
xs=intersect(xs,colnames(xy))
xy=xy[!is.na(xy[,trait]),]

####################### build data object for analysis
design="RDM"
id=xy[,psubid]
grp=NA
yi=xy[,trait]
xi=xy[,xs]
f=maf(xi)
if (sum(f>0.5,na.rm=T)>0) { xi[,f>0.5]=2-xi[,f>0.5]; f[f>0.5]=1-f[f>0.5] }
sele = (f>0 & f<=maf_cutoff & !is.na(f))


if (sum(sele)>1)
{
xi=xi[,sele ]
z=list(design=design,id=id,grp=grp,y=yi,x=xi)
#collapse.test(z,0)->rst
collapse.test(z,permun)->rst
rst\$gene=gene;rst\$trait=trait;rst\$maf=maf_cutoff
} #sele>1

} #(length(xs)>1)

if (is.null(rst)) save(rst,file=paste(out.dir,"/",trait,"_",gene,"_",".error",sep=""))
if (!is.null(rst)) save(rst,file=paste(out.dir,"/",trait,"_",gene,"_",".rdata",sep=""))

}
_END_OF_R_
    #-------------------------------------------------

    print $tfh_R_project "$R_command_project\n";

    my $cmd_project = "R --vanilla --slave \< $R_path_project";
    my $return_project = Genome::Sys->shellcmd(
        cmd => "$cmd_project",
    );
    unless($return_project) { 
        $self->error_message("Failed to execute: Returned $return_project");
        die $self->error_message;
    }

    #make .R file
    my ($tfh_R_bsub,$R_path_bsub) = Genome::Sys->create_temp_file;
    unless($tfh_R_bsub) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    $R_path_bsub =~ s/\:/\\\:/g;

    #-------------------------------------------------
    my $R_command_bsub = <<"_END_OF_R_";
source("$R_path_option")

gs=unique(m\$gene_name)
ys=unique(colnames(y)); ys=ys[ys!=psubid]

cmd=NULL
outs=dir(out.dir)
for (yi in ys) {
for (gi in gs) {

if (length(grep(paste(yi,gi,sep="_"),outs))==0)
{
cmd=c(cmd,paste("bsub 'R --no-save < $R_path_project",yi,gi,"'"))
}

}}


for (i in 1:length(cmd))
{
print(cmd[i])
print(paste(i,"of",length(cmd),"submitted") )
system(cmd[i])
}
_END_OF_R_
    #-------------------------------------------------

    print $tfh_R_bsub "$R_command_bsub\n";

    my $cmd_bsub = "R --vanilla --slave \< $R_path_bsub";
    my $return_bsub = Genome::Sys->shellcmd(
        cmd => "$cmd_bsub",
    );
    unless($return_bsub) { 
        $self->error_message("Failed to execute: Returned $return_bsub");
        die $self->error_message;
    }


    #make .R file
    my ($tfh_R_summary,$R_path_summary) = Genome::Sys->create_temp_file;
    unless($tfh_R_summary) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    $R_path_summary =~ s/\:/\\\:/g;

    #-------------------------------------------------
    my $R_command_summary = <<"_END_OF_R_";
in.dir="$temp_path_output"
dir(in.dir)->fs

fs=c(fs[-grep("error",fs)], fs[grep("error",fs)] )

##################################################### indv.
tt=NULL
for (i in 1:length(fs))
{
fi=fs[i]
load(paste(in.dir,fi,sep="/"))
strsplit(fi,split="_")->ids
trait=ids[[1]][1]
class=ids[[1]][2]
if (!is.null(rst)) 
{
vn=length(rst\$variants)
neg=sum(rst\$r1<0)
pos=sum(rst\$r1>0)
###collapse
p=cbind(trait,class,vn,neg,pos,t(as.data.frame(rst\$pp)))
###indv.
rst\$variants->variant
rst\$p1->p.value
#p=cbind(trait,class,variant,p.value)

}
if (is.null(rst)) 
{
vn=0
neg=0
pos=0
#p=cbind(trait,class,vn,neg,pos,t(rep(NA,7)))
p=NULL
}
tt=rbind(tt,p)
print(i)
}
head(tt)

write.csv(tt,file=paste(in.dir,"_burden.csv",sep=""),row.names=F,quote=F)

########################################################################

#FDR

read.csv(paste(in.dir,"_burden.csv",sep=""),header=T)->x

x\$fdr.x0=p.adjust(x\$x0,method="fdr")
x\$fdr.xp1=p.adjust(x\$xp1,method="fdr")
x\$fdr.HP=p.adjust(x\$HP,method="fdr")
x\$fdr.MB=p.adjust(x\$MB,method="fdr")

write.csv(x,file=paste(in.dir,"_burden_fdr.csv",sep=""),row.names=F,quote=F)

z=round(tapply(x\$vn,x\$class,mean))
z=z[order(names(z))]

#var number
barplot(sort(z,T), width = 1 ) 

# compare methods
for (ci in unique(x\$trait))
{
xi=x[x\$trait==ci,]
xi=xi[order(xi\$x0),]
png(paste(ci,".png",sep=""),800,600)
par(mfrow=c(3,1))
mts=c("CMC","WSS","sSum","PWST")
names(mts)=c("x0","MB","HP","xp1")
for (j in c("x0","MB","HP","xp1")[-3])
{
xj[xj==0]=NA
xj=-log10(xi[,j])
names(xj)=xi\$class
barplot(xj,main=paste(ci,mts[j]),cex.main=2,horiz=F,ylim=c(0,3.5))
}
dev.off()
}

# show gene

mts=c("CMC","WSS","sSum","PWST")
names(mts)=c("x0","MB","HP","xp1")
mts=mts[-3]
z=x[,c("trait","class",names(mts))]
colnames(z)=c("trait","class",mts)
z[rowSums(z[,-(1:2)]<=0.05,na.rm=T)>0,]->z





for (ci in unique(x\$trait))
{
xi=x[x\$trait==ci,]
xi=xi[order(xi\$x0),]
png(paste(ci,".png",sep=""),800,600)
par(mfrow=c(3,1))
mts=c("CMC","WSS","sSum","PWST")
names(mts)=c("x0","MB","HP","xp1")
for (j in c("x0","MB","HP","xp1")[-3])
{
xj[xj==0]=NA
xj=-log10(xi[,j])
names(xj)=xi\$class
barplot(xj,main=paste(ci,mts[j]),cex.main=2,horiz=F,ylim=c(0,3.5))
}
dev.off()
}
_END_OF_R_
    #-------------------------------------------------

    print $tfh_R_summary "$R_command_summary\n";

    my $cmd_summary = "R --vanilla --slave \< $R_path_summary";
    my $return_summary = Genome::Sys->shellcmd(
        cmd => "$cmd_summary",
    );
    unless($return_summary) { 
        $self->error_message("Failed to execute: Returned $return_summary");
        die $self->error_message;
    }










    return 1;
}


