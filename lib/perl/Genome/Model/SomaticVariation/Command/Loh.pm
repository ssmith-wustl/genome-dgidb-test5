package Genome::Model::SomaticVariation::Command::Loh;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;

class Genome::Model::SomaticVariation::Command::Loh {
    is => 'Genome::Command::Base',
    has =>[
        build_id => {
            is => 'Integer',
            is_input => 1,
            is_output => 1,
            doc => 'build id of SomaticVariation model',
        },
        build => {
            is => 'Genome::Model::Build::SomaticVariation',
            id_by => 'build_id',
        }
    ],
};

sub execute {
    my $self = shift;
    my $build = $self->build;
    unless(defined($build->loh_version)){
        $self->status_message("No LOH version was found, skipping LOH detection!");
        return 1;
    }
    unless ($build){
        die $self->error_message("no build provided!");
    }
    my $normal_build = $build->normal_build;
    unless ($normal_build){
        die $self->error_message("No previous normal build found on somatic build!");
    }
    #Use snvs bed for intersecting with bed style outputs from detect-variants
    
    my $normal_snvs;
    # Wrap this call in an eval so the whole process won't die if there's no bed, 
    # we will fall back on the annotation format, and temporarily convert it
    eval {
        $normal_snvs = $normal_build->filtered_snvs_bed; 
    };
    unless(defined($normal_snvs) && -e $normal_snvs){
        # in the event that no filtered_snvs_bed is found, fall back on samtools output, and convert that to bed
        unless($normal_snvs = $self->get_temp_bed_snvs($normal_build)){
            die $self->error_message("Could not find snvs_bed from normal reference-alignment build.");
        }
    }
    $self->status_message("Looking for LOH events in SNV output");

    my $version = 2;

    my $detected_snv_path = $build->data_set_path("variants/snvs.hq",$version,'bed'); 
    my $output_dir = $build->data_directory."/loh";
    unless(Genome::Sys->create_directory($output_dir)){
        die $self->error_message("Failed to create the ./loh subdir");
    }

    my $somatic_output = $output_dir."/snvs.somatic.v".$version.".bed";
    my $loh_output = $output_dir."/snvs.loh.v".$version.".bed";

    my $aligned_reads_input = $build->tumor_build->whole_rmdup_bam_file;
    my $control_aligned_reads_input = $build->normal_build->whole_rmdup_bam_file;
    my $reference_build_id = $build->reference_sequence_build->id;

    $self->run_loh( $normal_snvs, $detected_snv_path, $somatic_output, $loh_output );
    
    $self->status_message("Identify LOH step completed");
    return 1;
}

sub run_loh {
    my $self = shift;
    my ($control_variant_file,$detected_snvs,$somatic_output,$loh_output) = @_;

    my $somatic_fh = Genome::Sys->open_file_for_writing($somatic_output);
    my $loh_fh = Genome::Sys->open_file_for_writing($loh_output);

    my $normal_snp_fh = Genome::Sys->open_file_for_reading($control_variant_file);
    my $input_fh = Genome::Sys->open_file_for_reading($detected_snvs);

    #MAKE A HASH OF NORMAL SNPS!!!!!!!!!!!!!
    #Assuming that we will generally be doing this on small enough files (I hope). I suck. -- preserved in time from dlarson
    my %normal_variants;
    while(my $line = $normal_snp_fh->getline) {
        chomp $line;
        my ($chr, $start, $pos2, $ref,$var) = split /\t/, $line;
        my $var_iub;
        #Detect if ref and var columns are combined
        if($ref =~ m/\//){
            ($ref,$var_iub) = split("/", $ref);
        }
        else {
            $var_iub = $var;
        }
        #first find all heterozygous sites in normal
        next if($var_iub =~ /[ACTG]/);
        my @alleles = Genome::Info::IUB->iub_to_alleles($var_iub);
        $normal_variants{$chr}{$start} = join '',@alleles;
    }
    $normal_snp_fh->close;

    # Go through input variants. If a variant was called in both the input set and the control set (normal samtools calls):
    # If that variant was heterozygous in the control call and became homozygous in the input set, it is considered a loss of heterozygocity event, and goes in the LQ file
    # Otherwise it is not filtered out, and remains in the HQ output
    while(my $line = $input_fh->getline) {
        chomp $line;

        my ($chr, $start, $stop, $ref_and_iub) = split /\t/, $line;
        my ($ref, $var_iub) = split("/", $ref_and_iub);

        #now compare to homozygous sites in the tumor
        if ($var_iub =~ /[ACTG]/ && exists($normal_variants{$chr}{$start})) {
            if(index($normal_variants{$chr}{$start},$var_iub) > -1) {
                #then they share this allele and it is LOH
                $loh_fh->print("$line\n");
            }
            else {
                $somatic_fh->print("$line\n");
            }
        }
        else {
            $somatic_fh->print("$line\n");
        }
    }
    $input_fh->close;
    return 1;
}

# return a path to a temp file containing a bed version of the samtools style snv_file
sub get_temp_bed_snvs {
    my $self = shift;
    my $normal_build = shift;
    my $normal_snvs = $normal_build->snv_file;
    my $temp_bed_file = Genome::Sys->create_temp_file_path;

    my $convert = Genome::Model::Tools::Bed::Convert::Snv::SamtoolsToBed->create( 
                        source => $normal_snvs, 
                        output => $temp_bed_file);

    unless($convert->execute){
        die $self->error_message("Failed to run conversion from samtools to bed format");
    }
    return $temp_bed_file;
}

1;

