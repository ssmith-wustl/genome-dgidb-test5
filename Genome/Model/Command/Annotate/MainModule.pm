package Genome::Model::Command::Annotate::AmlReport;

use strict;
use warnings;

use above "Genome"; 

class Genome::Model::Command::Annotate::AmlReport
{
    is => 'Command',                       
    has => 
    [ 
    db_name => { type => 'String', doc => "?", is_optional => 0 },
    file => { type => 'String', doc => "?", is_optional => 0 },
    ], 
};

use Data::Dumper;
use IO::File;
use Genome::Model::Command::Annotate::GetGeneExpression;
use Genome::Model::Command::Annotate::GetAnnotationInfo;
use Genome::Model::Command::Annotate::Prioritize;
use Genome::Model::Command::Annotate::Sort;
use MG::Analysis::VariantAnnotation;
use MPSampleData::DBI;
use MPSampleData::ReadGroupGenotype;

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
    #$input_file = $self->_add_cdna_reads($input_file);
    @input_files = $self->_prioritize($input_file);
    foreach my $input_file ( @input_files )
    {
        $self->_remove_snps_submitted_for_validation($input_file);
    }

    return 1;
}

sub _get_annotation_info
{
    my ($self, $input) = @_;
    
    my $gai = Genome::Model::Command::Annotate::GetAnnotationInfo->new
    (
        input => $self->input,
    );

    $gai->execute;

    return $gai->output;
}

sub _get_gene_expression
{
    my ($self, $input) = @_;
    
    my $gge = Genome::Model::Command::Annotate::GetAnnotationInfo->new
    (
        file => $self->file,
        input => $input,
    );

    $gge->execute;

    return $gge->output;
}

sub _add_cdna_reads
{
    my ($self, $input) = @_;
    
    my $pri = Genome::Model::Command::Annotate::AddCdnaReads->new
    (
        input => $input,
    );

    $pri->execute;

    return $pri->output;
}

sub _prioritize
{
    my ($self, $input) = @_;
    
    my $pri = Genome::Model::Command::Annotate::Prioritize->new
    (
        input => $input,
    );

    $pri->execute;

    return $pri->outputs;
}

sub _remove_snps_submitted_for_validation
{
    my ($self, $input) = @_;
    
    my $rssfv = Genome::Model::Command::Annotate::RemoveSnpsSubmittedForValidation->new
    (
        input => $input,
    );

    $rssfv->execute;
    
    return $rssfv->output;
}

1;

#$HeadURL$
#$Id$
