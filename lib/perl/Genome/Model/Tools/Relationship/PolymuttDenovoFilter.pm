package Genome::Model::Tools::Relationship::PolymuttDenovoFilter;

use strict;
use warnings;
use Data::Dumper;
use Genome;           
use Genome::Info::IUB;
use POSIX;
our $VERSION = '0.01';
use Cwd;
use File::Basename;
use File::Path;

class Genome::Model::Tools::Relationship::PolymuttDenovoFilter {
    is => 'Command',
    has_optional_input => [
    model_group_id => {
        is_optional=>0,
        doc=>'id of model group for family',
    },
    denovo_vcf=> {
        is_optional=>0,
        doc=>'denovo vcf output for same family',
    },
    output_path=> {
        is_optional=>0,
        doc=>'binomial test outputs for each individual in the family',
    },

    ],


};

sub help_brief {
    "blahblahblah"
}

sub help_detail {
}
#/gscuser/dlarson/src/polymutt.0.01/bin/polymutt -p 20000492.ped -d 20000492.dat -g 20000492.glfindex --minMapQuality 1 --nthreads 4 --vcf 20000492.standard.vcf
sub execute {
    $DB::single=1;
    my $self=shift;
    my $mg_id = $self->model_group_id;
    my $vcf = $self->denovo_vcf;

    my $mg = Genome::ModelGroup->get($mg_id);
    my @models = $mg->models;
    @models = sort {$a->subject->name cmp $b->subject->name} @models;
    my $sites_file = Genome::Sys->create_temp_file_path();
    my $sites_cmd = qq/ zcat $vcf | cut -f1,2 | grep -v "^#" | awk '{OFS="\t"}{print \$1, \$2, \$2}' > $sites_file/;
    unless(-s $sites_file) {
        print STDERR "running $sites_cmd\n";
        `$sites_cmd`;
    }
###prepare readcounts
    my $ref_fasta=$models[0]->reference_sequence_build->full_consensus_path("fa");
    my $readcount_file_ref = $self->prepare_readcount_files($ref_fasta, $sites_file, \@models);
    my $vcf_fh;
    if(Genome::Sys->_file_type($vcf) eq 'gzip') {
        $vcf_fh = Genome::Sys->open_gzip_file_for_reading($vcf);
    }
    else {
        $vcf_fh = Genome::Sys->open_file_for_reading($vcf);
    }    
    my $r_input_path = $self->prepare_r_input($vcf_fh, $readcount_file_ref);
    my ($r_fh, $r_script_path) = Genome::Sys->create_temp_file();
    $r_fh->print($self->r_code($r_input_path, $self->output_path));
    $r_fh->close;
    `R --vanilla < $r_script_path`;
    return 1;
}

sub prepare_readcount_files {
    my $self = shift;
    my $ref_fasta = shift;
    my $sites_file = shift;
    my $model_ref = shift;
    my @readcount_files;
    for my $model (@$model_ref) {
        my $readcount_out = Genome::Sys->create_temp_file_path($model->subject->name . ".readcount.output");
        my $bam = $model->last_succeeded_build->whole_rmdup_bam_file;
        push @readcount_files, $readcount_out;
        my $readcount_cmd = "bam-readcount -q 1 -f $ref_fasta -l $sites_file $bam > $readcount_out";
        unless(-s $readcount_out) {
            print STDERR "running $readcount_cmd";
            print `$readcount_cmd`;
        }
    }
    return \@readcount_files;
}




1;
sub prepare_r_input {
    my $self = shift;
    my $vcf_fh=shift;
    my $readcount_files = shift;
    my ($r_input_fh,$r_input_path) = Genome::Sys->create_temp_file();
    while (my $line = $vcf_fh->getline) {
        next if ($line =~ m/^#/);
        chomp($line);
        my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split "\t", $line;
        my @possible_alleles = ($ref);
        my @alts = split ",", $alt;
        push @possible_alleles, @alts;
        my $novel=0;
        for (my $i = 0; $i < @samples; $i++) {
            my ($gt, $rest) = split ":", $samples[$i];
            my ($all1, $all2) = split "[|/]", $gt;
            unless(grep {/$all1/} @possible_alleles) {
                $novel = $all1;
            }
            unless(grep {/$all2/} @possible_alleles) {
                $novel = $all2;
            }

        }
        if($novel) {
            $r_input_fh->print("$chr\t$pos");
            for (my $i = 0; $i < @samples; $i++) {
                my $readcount_file = $readcount_files->[$i];
                chomp(my $readcount_line = `grep "^$chr\t$pos" $readcount_file`);
                my ($chr, $pos, $rc_ref, $depth, @fields) = split "\t", $readcount_line;
                my $prob;
                my ($gt, $rest) = split ":", $samples[$i];
                my @ref_bases = split "[|/]", $gt;
                if(grep /$novel/, @ref_bases) {
                    $prob = .5;
                    if($novel eq $ref_bases[0]) {
                        shift @ref_bases;
                    }else {
                        pop @ref_bases;
                    }         
                }
                else {
                    $prob = .001;
                }
                my $ref_depth=0;
                my $var_depth=0;
                if($readcount_line) {
                    for my $fields (@fields) { 
                        my ($base, $depth, @rest)  = split ":", $fields;
                        next if($base =~m/\+/);
                        if(grep {/$base/} @ref_bases) {
                            $ref_depth=$depth;
                        }
                        elsif($base eq $novel) {
                            $var_depth+=$depth;
                        }
                    }
                }
                $r_input_fh->print("\t$var_depth\t$ref_depth\t$prob");
            }
            $r_input_fh->print("\n");
        }
    }
    $r_input_fh->close;
    return $r_input_path;
}


sub r_code {
    my $self = shift;
    my $input_name = shift;
    my $output_name = shift;
    return <<EOS
options(stringsAsFactors=FALSE);
mytable=read.table("$input_name");
pvalue_matrix=matrix(nrow=nrow(mytable), ncol=4);
indices=c(3,6,9,12);
for (i in 1:nrow(mytable)) {  
    for (j in indices) { 
        pvalue_matrix[i,(j/3)]=binom.test(as.vector(as.matrix(mytable[i,j:(j+1)])), 0, mytable[i,(j+2)], "t", .95)\$p.value; 
    }
}
chr_pos_matrix=cbind(mytable\$V1,mytable\$V2, pvalue_matrix);
write(t(chr_pos_matrix), file="$output_name", ncolumns=6, sep="\t");
EOS
}

