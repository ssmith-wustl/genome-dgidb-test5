package Genome::Model::Command::Annotate::AmlReportChunker;

use strict;
use warnings;

use above "Genome";                

use Data::Dumper;
#use Genome::Model::Command::Annotate::AmlReportManager;
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
    process_profile_id => { type => 'String', doc => "?", is_optional => 0 },
    file_base => { type => 'String', doc => "?", is_optional => 0 },
    batch_size => { type => 'String', doc => "?", is_optional => 1 },
    launch_manager => { type => 'String', doc => "?", is_optional => 1 },
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

    MPSampleData::DBI->connect( $self->db_name );

    my ($process_profile) = MPSampleData::ProcessProfile->search
    (
        concatenated_string_id => $self->process_profile_id,
    );
    $self->error_message
    (
        sprintf
        (
            'Can\'t find process profile for concatenated_string_id (%s)', 
            $self->run_id,
        )
    )
        and return unless $process_profile;
    
    #print "CONNECTED\n"; return 1;

    # defaults
    my $batch_size = $self->batch_size || 300000;
    
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
        $self->error_message
        (
            sprintf
            (
                'Multiple read groups found for process profile concatenated_string_id (%s)',
                $self->run_id,
           )
        );
        # TODO Needed??
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

    #  print Dumper ( { pp_csi => $process_profile->concatenated_string_id, rg_id => $read_group->read_group_id, rg_count => $read_group_count, geno_count => $genotypes->count, }); return 1;
    
    my $fh = $self->_open_next_file;
    my $counter = 1;
    while ( my $genotype = $genotypes->next )
    {
        $fh->print($genotype->id,"\n");
        if ( $counter++ == $batch_size )
        {
            $fh->close;
            $fh = $self->_open_next_file;
            $counter = 1;
        }
    }
    $fh->close;

    $self->_launch_manager if $self->launch_manager;

    return 1;
}

my $file_counter = 1;
my @files;

sub _open_next_file
{
    my $self = shift;

    my $file = $self->_next_file;
    unlink $file if -e $file;
    my $fh = IO::File->new("> $file");
    $self->error_message("Can't open file ($file): $!")
        and return unless $fh;

    push @files, $file;

    return $fh;
}

sub files
{
    my $self = shift;

    return @files;
}

sub _next_file
{
    my $self = shift;

    return sprintf('%s.%d', $self->file_base, $file_counter++);
}

sub _launch_manager
{
    my $self = shift;
    
    #my $manager = Genome::Model::Command::Annotate::AmlReportManager->new();
    
    return 1;
}

1;

#$HeadURL$
#$Id$
