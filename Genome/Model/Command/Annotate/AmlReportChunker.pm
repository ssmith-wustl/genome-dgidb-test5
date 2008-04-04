package Genome::Model::Command::Annotate::AmlReportChunker;

use strict;
use warnings;

use above "Genome";                

use Data::Dumper;
use IO::File;
use LSF::Job;
use MPSampleData::DBI;
use MPSampleData::ProcessProfile;
use MPSampleData::ReadGroup;
use MPSampleData::ReadGroupGenotype;
use UR::DBI;
use XML::Simple ':strict';

class Genome::Model::Command::Annotate::AmlReportChunker 
{
    is => 'Command',                       
    has => 
    [   
    db_name => { type => 'String', doc => "?", is_optional => 0 },
    run_id => { type => 'String', doc => "?", is_optional => 0 },
    file => { type => 'String', doc => "?", is_optional => 0 },
    ], 
};

sub help_brief 
{
    "chunks aml report"                 
}

sub help_synopsis
{
    return <<EOS
genome-model annotate aml-report-chunker --dev <db_name> --run-id <run_id> --output <output_file> --create_input
EOS
}

sub help_detail
{
    return <<EOS 
EOS
}

sub execute 
{   
    my $self = shift;

    MPSampleData::DBI->connect($self->db_name);

    my ($process_profile) = MPSampleData::ProcessProfile->search(concatenated_string_id => $self->run_id);
    $self->error_message
    (
        sprintf
        (
            'Can\'t find process profile for concatenated_string_id (%s)', 
            $self->run_id,
        )
    )
        and return unless $process_profile;
    
    my $read_groups = $process_profile->read_groups;
    my $read_group_count = $read_groups->count;
    unless ( $read_group_count )
    {
        $self->error_message
        (
            sprintf
            (
                'No read groups found for process profile concatenated_string_id (%s)',
                $self->run_id,
            )
        );
        return;
    }
    elsif ( $read_group_count > 1)
    {
        # TODO Needed??
        #$self->error_message
        #(
        #    sprintf
        #    (
        #        'Multiple read groups found for process profile concatenated_string_id (%s)',
        #        $self->run_id,
        #   )
        #);
        #return;
    }
    my $read_group = $read_groups->first;

    my $genotypes = $read_group->genotypes;
    $self->error_message
    (
        sprintf
        (
            'No genotypes found for read group id and concat string id %s', 
            $read_group->read_group_id,
            $self->run_id,
        )
    )
        and return unless $genotypes->count;

    my $file = $self->file;
    unlink $file if -e $file;
    my $fh = IO::File->new("> $file");
    $self->error_message("Can't open file ($file): $!")
        and return unless $fh;

    # TODO add counter
    while ( my $genotype = $genotypes->next )
    {
        $fh->print($genotype->id,"\n");
    }

    $fh->close;

    return 1;
}

1;

