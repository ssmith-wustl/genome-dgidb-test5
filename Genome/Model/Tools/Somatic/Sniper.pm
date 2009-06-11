package Genome::Model::Tools::Somatic::Sniper;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Somatic::Sniper{
    is => ['Command','Genome::Software'],
    has => [
        tumor_file => {
            is  => 'String',
            is_input => '1',
            doc => 'The input tumor BAM file.',
        },
        normal_file => {
            is  => 'String',
            is_input => '1',
            doc => 'The input normal file',
        },
        output_file => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The somatic sniper output file.',
        },
        reference_file => {
            is  => 'String',
            default => '/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa', 
            doc => 'The somatic sniper reference file',
        },

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

sub resolve_software_version{
    my $self = shift;
    return 'test';
}

sub execute {
    my $self = shift;
    $DB::single = 1;

    if (-e $self->output_file) {
        $self->status_message("Skipping, output file exists");
        return 1;
    }

    $self->status_message("beginning execute");

    unless ( Genome::Utility::FileSystem->validate_file_for_reading($self->tumor_file) ) {
        $self->error_message("Could not validate tumor file:  ".$self->tumor_file );
        return;
    } 

    unless ( Genome::Utility::FileSystem->validate_file_for_reading($self->normal_file) ) {
        $self->error_message("Could not validate normal file:  ".$self->normal_file );
        return;
    } 
    
    
    #check for result
    
    my $inputs_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params('Genome::Model::Tools::Somatic::Sniper',tumor_file => $self->tumor_file, normal_file => $self->normal_file, output_file => $self->output_file, reference_file => $self->reference_file );  #TODO, I don't really think output file should be a part of these params here, up for debate though
    

# Skip this for now until we figure out how we want to do this
=cut
    my $software_result = Genome::SoftwareResult->get(inputs_bx => $inputs_bx);

    if ($software_result){
        $self->status_message("Found previous execution of sniper with these params, skipping!");
        system('touch /gscuser/adukes/svn/perl_modules/Genome/Model/Tools/Somatic/result_found');
        return $software_result->output;
    }
=cut

    my $cmd = "~charris/c-src-BLECH/samtools_somatic_copy/samtools somaticsniper -f ".$self->reference_file." ".$self->tumor_file." ".$self->normal_file ." > " . $self->output_file; 
    my $result = Genome::Utility::FileSystem->shellcmd( cmd=>$cmd, input_files=>[$self->tumor_file,$self->normal_file], output_files=>[$self->output_file], skip_if_output_is_present=>0 );

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
