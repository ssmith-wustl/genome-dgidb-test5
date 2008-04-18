package Genome::Model::Command::Annotate::MainModule;

use strict;
use warnings;

use above "Genome"; 

use Data::Dumper;
use IO::File;
use Genome::Model::Command::Annotate::AddCdnaReads;
use Genome::Model::Command::Annotate::GetGeneExpression;
use Genome::Model::Command::Annotate::GetAnnotationInfo;
use Genome::Model::Command::Annotate::Prioritize;
use Genome::Model::Command::Annotate::RemoveSnpsSubmittedForValidation;
use MG::Analysis::VariantAnnotation;
use MPSampleData::DBI;
use MPSampleData::ReadGroupGenotype;

class Genome::Model::Command::Annotate::MainModule
{
    is => 'Command',                       
    has => 
    [ 
    db_name => { type => 'String', doc => "?", is_optional => 0 },
    input => { type => 'String', doc => "?", is_optional => 0 },
    ], 
};

sub help_brief {   
    "WRITE A ONE-LINE DESCRIPTION HERE"                 
}

sub help_synopsis { 
    return <<EOS
genome-model example1 --foo=hello
genome-model example1 --foo=goodbye --bar
genome-model example1 --foo=hello barearg1 barearg2 barearg3
EOS
}

sub help_detail {
    return <<EOS 
This is a dummy command.  Copy, paste and modify the module! 
CHANGE THIS BLOCK OF TEXT IN THE MODULE TO CHANGE THE HELP OUTPUT.
EOS
}

sub execute 
{ 
    my $self = shift;

    my $input_file = $self->input;
    $input_file = $self->_get_annotation_info($input_file);
    $input_file = $self->_get_gene_expression($input_file);
    $input_file = $self->_add_cdna_reads($input_file);
    my @input_files = $self->_prioritize($input_file);
    foreach my $input_file ( @input_files )
    {
        $self->_remove_snps_submitted_for_validation($input_file);
    }

    return 1;
}

sub _get_annotation_info
{
    my ($self, $input) = @_;
    
    my $output = $input . '.gai';
    unlink $output if -e $output;

    system sprintf
    (
        "genome-model annotate get-annotation-info --db-name %s --input %s --output %s",
        $self->db_name,
        $input,
        $output,
    );
    
    return $output;
}

sub _get_gene_expression
{
    my ($self, $input) = @_;

    my $output = $input . '.gge';
    unlink $output if -e $output;

    system sprintf
    (
        "genome-model annotate get-gene-expression --db-name %s --input %s --output %s",
        $self->db_name,
        $input,
        $output,
    );
    
    return $output;
}

sub _add_cdna_reads
{
    my ($self, $input) = @_;

    my $output = $input . '.gge';
    unlink $output if -e $output;

    system sprintf
    (
        "genome-model annotate add-cdna-reads --db-name %s --input %s --output %s",
        $self->db_name,
        $input,
        $output,
    );
    
    return $output;
}

sub _prioritize
{
    my ($self, $input) = @_;

    my $output1 = $input . '.1';
    unlink $output1 if -e $output1;
    my $output2 = $input . '.2';
    unlink $output2 if -e $output2;

    system sprintf
    (
        "genome-model annotate prioritize --input %s --priority1-output %s --priority2-output %s",
        $input,
        $output1,
        $output2,
    );
    
    return ($output1, $output2);
}

sub _remove_snps_submitted_for_validation
{
    my ($self, $input) = @_;

    my $output = $input . '.rssfv';
    unlink $output if -e $output;

    system sprintf
    (
        "genome-model annotate remove-snps-submitted-for-validation --input %s --output %s",
        $input,
        $output,
    );
    
    return $output;
}

1;

#$HeadURL$
#$Id$
