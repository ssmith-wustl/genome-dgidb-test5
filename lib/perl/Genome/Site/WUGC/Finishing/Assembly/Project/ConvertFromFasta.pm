package Genome::Site::WUGC::Finishing::Assembly::Project::ConvertFromFasta;

use strict;
use warnings;

use Finfo::Std;

use Bio::SeqIO;
use Data::Dumper;
use Genome::Site::WUGC::Finishing::Assembly::Project::Utils;
use IO::File;

my %namer :name(namer:r)
    :isa('object Genome::Site::WUGC::Finishing::Assembly::Project::Namer');
my %fasta :name(fasta:r) 
    :isa(file_r)
    :desc('Fasta file');
my %xml :name(xml:r)
    :isa('object Genome::Site::WUGC::Finishing::Assembly::Project::XML');
my %proj_db :name(project_db:r)
    :isa([ 'in_list', Genome::Site::WUGC::Finishing::Assembly::Factory->available_dbs ])
    :desc('DB to create project in: ' . join(', ', Genome::Site::WUGC::Finishing::Assembly::Factory->available_dbs));
my %ctg_db :name(contig_db:r)
    :isa([ 'in_list', Genome::Site::WUGC::Finishing::Assembly::Factory->available_dbs ])
    :desc('DB source of contigs: ' . join(', ', Genome::Site::WUGC::Finishing::Assembly::Factory->available_dbs));
my %rename_contigs :name(rename_contigs:o)
    :isa('in_list renumber include_project_name renumber_and_include')
    :default(0)
    :desc('This will rename the contigs when the project is checked out.  Options are: renumber (renumbers the contigs, starting at 1), include_project_name (adds the project name to the front of the contig name) and renumber_and_include (does both)');
my %file_info :name(file_info:o) 
    :isa(string)
    :desc('File (ace or sqlite) pattern, will replace \'[]\' with contig lookup number');
my %ctg_pattern :name(pattern:o)
    :isa(string)
    :default('(Contig\d+(\.\d+)?)')
    :clo('ctg-pattern=s')
    :desc('Pattern to parse for contigs');

sub utils : PRIVATE
{
    return Genome::Site::WUGC::Finishing::Project::Utils->instance;
}

sub execute
{
    my $self = shift;

    my $file = $self->source_file;

    my $seqio = Bio::SeqIO->new('-file' => $file, '-format' => 'Fasta');

    $self->fatal_msg("Could not create Bio::SeqIO for file ($file)")
        and return unless $seqio;

    my $projects = {};
    while ( my $seq = $seqio->next_seq )
    {
        my $name = $self->namer->next_name;
        my $pattern = $self->pattern;
        #TODO
        my $ctg_namer = Genome::Site::WUGC::Finishing::Project::Namer->new
        (
            base_name => sprintf
            (
                '%sContig',
                ( $self->include_proj_in_ctg ) ? $name : '' 
            ),
        );

        my @ctgs;
        foreach my $ctg ( $seq->id =~ /$pattern/g ) #(Contig\d+\.\d+)
        {
            my $file;
            if ( $file = $self->file_info )
            {
                my $num = Genome::Site::WUGC::Finishing::Assembly::Project::Utils->instance->contig_lookup_number($ctg);
                $file =~ s/\[\]/$num/;
            }

            my $ctg_attrs = 
            {
                name => $ctg_namer->next_name,
                db => $self->contig_db,
            };
            $ctg_attrs->{file} = $file if $file;
            push @ctgs, $ctg_attrs;
        }

        $projects->{$name} = { db => $self->project_db };
        $projects->{contigs} = \@ctgs if @ctgs;
    }

    $self->fatl_msg( sprintf('No projects found in fasta (%s)', $self->fasta) ) unless %$projects;
    
    $self->xml->write_projects($projects);
    
    return 1;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Assembly/Project/ConvertFromFasta.pm $
#$Id: ConvertFromFasta.pm 31534 2008-01-07 22:01:01Z ebelter $
