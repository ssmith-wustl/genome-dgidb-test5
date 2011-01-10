package Genome::Model::Tools::Xhong::Germline;

use Genome;
use IO::File;
use Command;

use strict;
use warnings;

class Genome::Model::Tools::Xhong::Germline {
    is => 'Command',
    has => [
    somatic_build_ids => { 
        type => 'String', 
        is_optional => 1, 
        doc => "somatic build id to process, supply this option only if the model_group_name is not avaliable", 
    },
    model_group_name=>{
        type=>'String', 
        is_optional => 0, 
        doc => "somatic model group name to process", 
    },
    analysis_dir => { 
        type => 'String', 
        is_optional => 1, 
        doc => "Directory where the snp files should be, by default it will be in /gscmnt/sata197/info/medseq/PCGP_Analysis/Germline/", 
    },
#        force => { type => 'Boolean', is_optional => 1, default => 0, doc => "whether or not to directory exists, make new copy of snps files." , },
    ]
};

sub help_brief {
    "copy all snp files to make tar.gz to transfer to SJ"
}

sub help_detail {
    <<'HELP';
This script will calculate the ratio of nonsense:missense in the predicted Germline SNV events in each individual case
HELP
}

sub execute {
    my $self=shift;
    $DB::single = 1;
    my %case ={};
    my @genome=();

    my $analysis_dir="/gscmnt/sata197/info/medseq/PCGP_Analysis/Germline/";
    if ($self->analysis_dir){
        $analysis_dir = $self->analysis_dir;
    }
    my @builds;

    my $rate_file;my $output_dir;
    if($self->somatic_build_ids) {
        @builds = map { Genome::Model::Build->get($_) } split /,/, $self->somatic_build_ids;
    }
    elsif($self->model_group_name) {
        my $group = Genome::ModelGroup->get(name => $self->model_group_name);
        @builds = grep { defined $_ } map {$_->last_succeeded_build ? $_->last_succeeded_build : $_->current_running_build ? $_->current_running_build : undef } $group->models;
    }
    foreach my $build (@builds) {
        my $tumor_build = $build->tumor_build;
        my $normal_build = $build->normal_build;
        my $tumor_snps =  $tumor_build->filtered_snp_file;
        my $normal_snps = $normal_build->filtered_snp_file;
        my $genome_name = $tumor_build->model->subject->source_common_name;
        $rate_file=$genome_name;
        $output_dir= "$analysis_dir/$genome_name";
        while(!(-e $output_dir)){
            unless( -e $output_dir){
                mkdir $output_dir,0755;
            }
            unless( -e $output_dir){
                $self->error_message("$output_dir doesn't exist");
                die;
            }
        }
        my $output="$output_dir/$genome_name.germline_snps";
        print "$output\n$normal_snps\n$tumor_snps\n";

        # intersect tumor normal snps
        my $jobid=`bsub -J '$genome_name.inter' gmt snp intersect $tumor_snps $normal_snps -i $output`;
        print "bsub gmt snp intersect $tumor_snps $normal_snps -i $output\n";
        $jobid=~/<(\d+)>/;
        $jobid= $1;
        print "sno intersect $jobid\n";

        # fast-tiering snps
        # TODO:  need to check wether the input file have to be the bed_format
        my $jobid2=`bsub -w 'ended($jobid)' -J '$genome_name.tier' gmt annotate fast-tier --variant-file=$output`;
        print "bsub -w 'ended($jobid)' gmt annotate fast-tier --variant-file=$output\n";
        $jobid2=~/<(\d+)>/;
        $jobid2= $1;
        print "fast-tier $jobid2\n";

        my $tier1="$output.tier1";
        my $before="$tier1.before";
        my $anno="$tier1.anno";

# potential dbSNP filter
# gmt annotate lookup-variants --append-rs-id --report-mode full --variant-file  --output-file

        #change file format of tier1
        my $jobid3=`bsub -w 'ended($jobid2) && ended($jobid)'-J '$genome_name.parse' "awk \'\{OFS\=\\\"\\\\t\\\";print \\\$1,\\\$2,\\\$2,\\\$3,\\\$4\}\' $tier1 \> $before"`;
        #my $jobid3=`bsub -w 'ended($jobid2) && ended($jobid)' 'perl /gscuser/xhong/git/genome/lib/perl/Genome/Model/Tools/Xhong/parsetab.pl $output $output.before'`;
        #print "bsub -w 'ended($jobid2) && ended($jobid)' 'perl /gscuser/xhong/git/genome/lib/perl/Genome/Model/Tools/Xhong/parsetab.pl $output $output.before'\n";
        $jobid3=~/<(\d+)>/;
        $jobid3= $1;
        print "awk $jobid3\n";

        #annotate tier1
        my $jobid4=`bsub -w 'ended($jobid3) && ended($jobid2)' -J '$genome_name.anno' gmt annotate transcript-variants --variant-file $before --output-file $anno --annotation-filter top`;
        print "bsub -w 'ended($jobid3)  && ended($jobid2)' gmt annotate transcript-variants --variant-file $before --output-file $anno --annotation-filter top\n";
        $jobid4=~/<(\d+)>/;
        $jobid4= $1;
        print "anno $jobid4\n";
        $case{$genome_name}=$anno;
        push @genome, $genome_name;
    }

    # wait all the annotation is done.
    my $all_done=1;
    while($all_done){
        $all_done=0;
        for my $genome_name(@genome){
            my$annofile=$case{$genome_name};
            unless (-e $annofile){
                #	$self->error_message("cannot find $annofile");
                sleep (600);
                $all_done=1;
            }
        }
    }

    # calcualte rate
    $rate_file=~/<\w+>/;
    $rate_file="$output_dir/".$rate_file.".rate";
    open(O, ">$rate_file") or die "cannot creat $rate_file";
    print O "Total\tMissense\t(R)\tnonsense\t(R)\n";
    for my $genome_name(@genome){
        my$annofile=$case{$genome_name};
        my $total=`wc -l $annofile`;
        $total=~/<(\d+)>/;
        my $missense=`grep missense $annofile|wc -l`;
        $missense=~/<(\d+)>/;
        my $nonsense=`grep nonsense $annofile|wc -l`;
        $nonsense=~/<(\d+)>/;
        my $missense_rate=$missense/$total;
        my $nonsense_rate=$nonsense/$total;
        print O "$total\t$missense\t$missense_rate\t$nonsense\t$nonsense_rate\n";	
    }
    close O;
}

