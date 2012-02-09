package Genome::Model::Tools::Relationship::CompoundHet;

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

class Genome::Model::Tools::Relationship::CompoundHet {
    is => 'Command',
    has_optional_input => [
    input_family_vcf=> {
        is=>'Text',
        is_optional=>0,
        doc=>"family vcf you want to search for compound hets",
    },
    vcf_output=>{
        is=>'Text',
        is_optional=>0,
        doc=>"output file of any possible compound het sites",
    },
    tiering_dir => {
        is=>'Text',
        is_optional=>1,
        default=>"/gscmnt/ams1102/info/model_data/2771411739/build106409619/annotation_data/tiering_bed_files_v3/",
        doc=>"build37 combined annotation 58_37c_v2... no ensembl only files at the time of this code being written"
    },
    ],
    has_param => [
    lsf_resource => {
        is => 'Text',
        default => "-R 'span[hosts=1] rusage[mem=1000] -n 4'",
    },
    lsf_queue => {
        is => 'Text',
        default => 'long',
    },
    ],


};

sub help_brief {
    "simulates reads and outputs a name sorted bam suitable for import into Genome::Model"
}

sub help_detail {
}
#/gscuser/dlarson/src/polymutt.0.01/bin/polymutt -p 20000492.ped -d 20000492.dat -g 20000492.glfindex --minMapQuality 1 --nthreads 4 --vcf 20000492.standard.vcf
sub execute {
    my $self = shift;
    my $tier1_positions_bed = $self->find_tier1($self->input_family_vcf);
    my $tier1_vcf = $self->subset_vcf($self->input_family_vcf, $tier1_positions_bed);
    my $tier1_vcf = "12937.tier1.vcf"; 
#  my $annotation_file= $self->run_vep($tier1_vcf);
    my $annotation_file = "/gscuser/charris/git/new_pipeline/genome/lib/perl/Genome/Model/Tools/Relationship/12937.tier1.vcf.annotated";
    my $final_output_tmp = $self->find_compound_hets($annotation_file, $tier1_vcf);
    my $final_output = $self->vcf_output;
    Genome::Sys->shellcmd(cmd=>"cp $final_output_tmp $final_output");

    return 1;
}

1;


sub find_tier1 {
    my ($self, $vcf_file) = @_;
    my $inFh;
    if(Genome::Sys->_file_type($vcf_file) eq 'gzip') {
        $inFh = Genome::Sys->open_gzip_file_for_reading($vcf_file);
    }
    else {
        $inFh = Genome::Sys->open_file_for_reading($vcf_file);
    }
    my ($temp_bed_fh,$temp_bed_path) = Genome::Sys->create_temp_file();
    while(my $line = $inFh->getline) {
        next if $line =~m/^#/;
        my ($chr, $pos, @fields) = split "\t", $line;
        my $start = $pos -1;
        my $stop = $pos;
        $temp_bed_fh->print("$chr\t$start\t$stop\n");
    }
    $temp_bed_fh->close;
    my $tier_files = $self->tiering_dir;
    my $fasttier = Genome::Model::Tools::FastTier::FastTier->create(
        variant_bed_file=>$temp_bed_path,
        tier_file_location=>$tier_files,
    );
    $fasttier->execute();
    my $tier1_file = $fasttier->tier1_output;
    return $tier1_file;
}

sub subset_vcf {
    my ($self, $input_vcf, $bed_restriction) = @_;
    my $output = Genome::Sys->create_temp_file_path();
    my $cmd ="intersectBed -a $input_vcf -wa -b $bed_restriction -u > $output";
    Genome::Sys->shellcmd(cmd=>$cmd);
    return $output;
}

sub run_vep {
    my ($self, $tier1_vcf) = shift;
    my $vep_output = Genome::Sys->create_temp_file_path();
#genome db ensembl vep --format vcf --input-file 12937.tier1.vcf --output-file 12937.tier1.vcf.annotated --polyphen b --per-gene --sift b --condel b
    my $VEP = Genome::Db::Ensembl::Vep->create( format=>"vcf",
        input_file=>$tier1_vcf,
        output_file=>$vep_output,
        polyphen=>"b",
        per_gene=>1,
        sift=>"b",
        condel=>"b"
    );
    $VEP->execute();
    return $vep_output;
}    


sub find_compound_hets {
    my ($self, $annotation_file, $tier1_vcf) = @_; 
    my %multi_hit_hash;
    $DB::single=1;
    my $anno_fh = Genome::Sys->open_file_for_reading($annotation_file);
    my $vcf_hash = $self->load_tier1_file($tier1_vcf);
    while(my $line = $anno_fh->getline) {
        next if ($line =~ m/^#/);
        my ($key, $chr_pos, $variant, $gene, $transcript, $the_word_transcript, $var_type, $c_pos, $other_pos, $some_number, $codon_change, $dash, $sift_polyphen_scores)= split "\t", $line;
        if($var_type eq 'NON_SYNONYMOUS_CODING') {
            $multi_hit_hash{$gene}{$key}=$line;
        }
    }
    my ($vcf_output_fh, $temp_final_vcf) = Genome::Sys->create_temp_file();
    for my $gene (sort keys %multi_hit_hash) {
        if(scalar(keys %{$multi_hit_hash{$gene}}) > 1) { # two non synonymous hits
            my @relevant_lines;
            for my $key (sort keys %{$multi_hit_hash{$gene}}) {
                my ($chr, $pos, $ref_var) = split "_", $key;
                push @relevant_lines,  $vcf_hash->{$chr}->{$pos};
            }
            if(my @two_hets = $self->possible_compound_het(@relevant_lines)) {
                $vcf_output_fh->print(@two_hets);  
            } 
        }
    }
    $vcf_output_fh->close;
    return $temp_final_vcf;
}

sub load_tier1_file {
    my ($self, $tier1_vcf) = @_;
    my %tier1_hash;
    my $vcf_fh = Genome::Sys->open_file_for_reading($tier1_vcf);
    while(my $line = $vcf_fh->getline) {
        my ($chr, $pos, @fields) = split "\t", $line;
        $tier1_hash{$chr}{$pos}=$line;
    }
    return \%tier1_hash;
} 

sub possible_compound_het {
    my ($self, @lines) = @_;
    my ($parent1, $parent2)= (0,0);
    my @lines_to_return;
    for my $line (@lines) {
        my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split "\t", $line;
        my ($parent1_gt, $parent2_gt, $child_gt) = $self->get_gts(@samples);
        if(($parent2==0) && ($parent1_gt eq '0/0') && ($parent2_gt ne '0/0') && ($child_gt ne '0/0')) {
            $parent2 = 1;
        }
        if(($parent1==0) && ($parent1_gt ne '0/0') && ($parent2_gt eq '0/0') && ($child_gt ne '0/0')) {
            $parent1=1;
        }
        if(($parent1_gt eq '0/0') || ($parent2_gt eq '0/0')) {
            push @lines_to_return, $line;
        }
    }
    if($parent1 && $parent2) {
        return (@lines_to_return);
    }
    return undef;
}


sub get_gts {
    my ($self, @samples) = @_;
    my @gts;
    for my $sample (@samples) { 
        my ($gt, @fields) = split ":", $sample;
        push @gts, $gt;
    }
    return @gts;
}







