package Genome::Site::WUGC::Finishing::Project::StepExecutor;

use strict;
use warnings;

use base qw(Finfo::Object);

use Data::Dumper;
use File::Basename;
use PP::LSF;

sub _attrs
{
    my $self = shift;

    return
    {
        'steps:r' =>
        {
            type => 'non_empty_aryref',
        },
        'params:r' =>
        {
            type => 'non_empty_hashref',
        },
    };
}

sub run
{
    my $self = shift;

    foreach my $step ( @{ $self->steps } )
    {
        $self->error_msg(sprintf('Unsupported step (%s)', $step))
            and return unless $self->can($step);
        $self->info_msg(sprintf('Executing step (%s)', $step));
        $self->$step
            or return;
    }
    
    return 1;
}

sub _execute_af_splitter
{
    my $self = shift;

    #my $params = $self->params;
    my $projects = $self->params->{acefile_splitter}->execute
        or return;

    $self->params->{projects} = $projects;
    
    return $projects;
}

sub _execute_writer
{
    my $self = shift;

    return unless $self->params->{projects};

    return 1 unless $self->params->{writer};
    
    return $self->params->{writer}->write_many( $self->params->{projects} );
}

sub _execute_reader
{
    my $self = shift;

    return unless $self->params->{reader};

    $self->params->{projects} = $self->params->{reader}->all
        or return;

    return 1;
}

sub _collect_contigs_and_create_acefiles
{
    my $self = shift;

    return unless $self->params->{projects};
    return unless $self->params->{dir};
    
    my $collector = Genome::Site::WUGC::Finishing::Project::ContigCollector->instance;
    
    foreach my $project ( @{ $self->params->{projects} } )
    {
        $self->info_msg("Creating acefile for " . $project->{name});

        my $ace = GSC::IO::Assembly::Ace->new()
            or die;

        my $ctgs = $collector->collect($project)
            or die;

        foreach my $ctg ( @$ctgs )
        {
            $ace->add_contig($ctg);
        }

        $ace->write_file
        (
            output_file => sprintf('%s/%s.fasta.screen.ace', $self->params->{dir}, $project->{name})
        );
    }

    return 1;
}

1;

=pod

=head1 Name

 Project::Maker

=head1 Synopsis

=head1 Usage

=head1 Methods

=head1 Disclaimer

 Copyright (C) 2007 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)


 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Project/ProcessExecutor.pm $
#$Id: ProcessExecutor.pm 29849 2007-11-07 18:58:55Z ebelter $
