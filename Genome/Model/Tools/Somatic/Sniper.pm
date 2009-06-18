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
        tumor_model => { is => 'Genome::Model',
                         id_by => 'tumor_model_id',
                         is_optional => 1,
                     },
        normal_model => { is => 'Genome::Model',
                         id_by => 'normal_model_id',
                         is_optional => 1,
                     },
        
        tumor_model_id => { is_input=>1, is=>'integer', is_optional=>0},
        normal_model_id => {is_input=>1, is=>'integer',is_optional=>0},
            
         _tumor_file => {
                is  => 'String',
            #  is_input => '1',
                is_optional=>1,            
               doc => 'The input tumor BAM file.',
              },
               _normal_file => {
                    is  => 'String',
                #        is_input => '1',
                is_optional => 1,
                   doc => 'The input normal file',
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

    #this may be removed later because it seems to skip this step perhaps without warning
    if (-e $self->output_snp_file && -e $self->output_indel_file) {
        $self->status_message("Skipping, output file exists");
        return 1;
    }
    unless($self->tumor_model) {
        $self->error_message("Unable to find tumor model for: " . $self->tumor_model_id);
    }
    unless($self->normal_model) {
        $self->error_message("Unable to find normal model for: " . $self->normal_model_id);
    }
    $self->status_message("beginning execute");
    
    $self->_tumor_file($self->tumor_model->last_complete_build->whole_rmdup_bam_file);
    $self->_normal_file($self->normal_model->last_complete_build->whole_rmdup_bam_file);

    unless ( Genome::Utility::FileSystem->validate_file_for_reading($self->_tumor_file) ) {
        $self->error_message("Could not validate tumor file:  ".$self->_tumor_file );
        return;
    } 

    unless ( Genome::Utility::FileSystem->validate_file_for_reading($self->_normal_file) ) {
        $self->error_message("Could not validate normal file:  ".$self->_normal_file );
        return;
    } 
    
    
    #check for result
    
    my $inputs_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params('Genome::Model::Tools::Somatic::Sniper',_tumor_file => $self->_tumor_file, _normal_file => $self->_normal_file, output_file => $self->output_file, reference_file => $self->reference_file );  #TODO, I don't really think output file should be a part of these params here, up for debate though
    

# Skip this for now until we figure out how we want to do this
=cut
    my $software_result = Genome::SoftwareResult->get(inputs_bx => $inputs_bx);

    if ($software_result){
        $self->status_message("Found previous execution of sniper with these params, skipping!");
        system('touch /gscuser/adukes/svn/perl_modules/Genome/Model/Tools/Somatic/result_found');
        return $software_result->output;
    }
=cut

    my $cmd = "~charris/c-src-BLECH/samtools_somatic_copy/samtools somaticsniper -Q " . $self->quality_filter. " -f ".$self->reference_file." ".$self->_tumor_file." ".$self->_normal_file ." " . $self->output_snp_file . " " . $self->output_indel_file; 
    my $result = Genome::Utility::FileSystem->shellcmd( cmd=>$cmd, input_files=>[$self->_tumor_file,$self->_normal_file], output_files=>[$self->output_file], skip_if_output_is_present=>0 );

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
