package Genome::Model::Tools::Somatic::Sniper;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Somatic::Sniper {
    is => ['Command','Genome::Software'],
    has => [
        tumor_bam_file => { 
            is  => 'String',
            is_input=>1, 
            doc => 'The input tumor BAM file.',
        },
        normal_bam_file => { 
            is  => 'String',
            is_input=>1, 
            doc => 'The input normal BAM file.',
        },
        output_snp_file => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The somatic sniper output file.',
        },
        output_indel_file => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The somatic sniper output file.',
        },
        quality_filter => {
            is => 'Integer',
            is_input=>1,
            is_optional=>1, 
            doc=>'minimum somatic quality to include in the snp output. default is 15.',
            default=>15,
        },
        reference_file => {
            is  => 'String',
            default => '/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa', 
            doc => 'The somatic sniper reference file',
        },
        # Make workflow choose 64 bit blades
        lsf_resource => {
            default_value => 'rusage[mem=4000] select[type==LINUX64] span[hosts=1]',
        } 
    ],
};

sub help_brief {
    "Produces a list of high confidence somatic snps.";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    Produces a list of high confidence somatic snps.
EOS
}

sub help_detail {                           
    return <<EOS 
    Provide a tumor and normal BAM file and get a list of somatic snps.  
EOS
}

my $error_fh;

sub resolve_software_version{
    my $self = shift;
    return 'test';
}

sub error_message {
    my $self=shift;
    my $line =shift;
    unless($error_fh) {
        $error_fh = IO::File->new("/gscmnt/sata820/info/medseq/somatic_pipeline/Sniper_error.out",">");
    }
    $error_fh->print($line);
    $self->SUPER::error_message($line);
}

sub status_message {
    my $self=shift;
    my $line =shift;
    unless($error_fh) {
        $error_fh = IO::File->new("/gscmnt/sata820/info/medseq/somatic_pipeline/Sniper_error.out",">");
    }
    $error_fh->print($line);
    $self->SUPER::status_message($line);
}



sub execute {
    my $self = shift;
    $DB::single = 1;

    # Skip if both output files exist... not sure if this should be here or not
    if ((-s $self->output_snp_file)&&(-s $self->output_indel_file)) {
        $self->status_message("Both output files are already present... skip sniping");
        return 1;
    }

    $self->status_message("beginning execute");
    
    unless ( Genome::Utility::FileSystem->validate_file_for_reading($self->tumor_bam_file) ) {
        $self->error_message("Could not validate tumor file:  ".$self->tumor_bam_file );
        return;
    } 

    unless ( Genome::Utility::FileSystem->validate_file_for_reading($self->normal_bam_file) ) {
        $self->error_message("Could not validate normal file:  ".$self->normal_bam_file );
        return;
    } 

    #check for result
    $DB::single=1;
    
    my $inputs_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params('Genome::Model::Tools::Somatic::Sniper',tumor_bam_file => $self->tumor_bam_file, normal_bam_file => $self->normal_bam_file, output_snp_file => $self->output_snp_file, output_indel_file => $self->output_indel_file,reference_file => $self->reference_file );  #TODO, I don't really think output file should be a part of these params here, up for debate though
    

# Skip this for now until we figure out how we want to do this
=cut
    my $software_result = Genome::SoftwareResult->get(inputs_bx => $inputs_bx);

    if ($software_result){
        $self->status_message("Found previous execution of sniper with these params, skipping!");
        system('touch /gscuser/adukes/svn/perl_modules/Genome/Model/Tools/Somatic/result_found');
        return $software_result->output;
    }
=cut

    $DB::single=1;
    my $cmd = "bam-somaticsniper -Q " . $self->quality_filter. " -f ".$self->reference_file." ".$self->tumor_bam_file." ".$self->normal_bam_file ." " . $self->output_snp_file . " " . $self->output_indel_file; 
    my $result = Genome::Utility::FileSystem->shellcmd( cmd=>$cmd, input_files=>[$self->tumor_bam_file,$self->normal_bam_file], output_files=>[$self->output_snp_file,$self->output_indel_file], skip_if_output_is_present=>0 );

# Skip this for now until we figure out how we want to do this
=cut
    if ($result == 1){
        my $software_result = Genome::SoftwareResult->create(
            software => $self,
            software_version => 'test',
            result_class_name => 'Genome::SoftwareResult',
            inputs_bx => $inputs_bx,
            output => $self->output_file,
        );
        if ($software_result){
            $self->status_message("created software result successfully");
            system('touch /gscuser/adukes/svn/perl_modules/Genome/Model/Tools/Somatic/created_result');
        }else{
            $self->error_message("failed to create software result");
        }
    }
=cut

    $self->status_message("ending execute");
    $DB::single=1;
    return $result; 
}

1;
