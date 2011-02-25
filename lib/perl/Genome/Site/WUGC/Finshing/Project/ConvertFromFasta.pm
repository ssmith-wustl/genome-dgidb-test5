package Finishing::Project::ConvertFromFasta;

use strict;
use warnings;

use Finfo::Std;

use Bio::SeqIO;
use Data::Dumper;
use Finishing::Project::Utils;
use IO::File;

my %namer :name(namer:r)
    :type(inherits_from)
    :options([qw/ Finishing::Project::Namer /]);
my %fasta :name(fasta:r) 
    :type(input_file)
    :clo('fasta=s') 
    :desc('Fasta file');
my %writer :name(writer:r)
    :type(inherits_from)
    :options([qw/ Finishing::Project::Writer /]);
my %type :name(type:r)
    :type(in_list)
    :options([ Finishing::Project::Utils->valid_project_types ])
    :clo('type=s')
    :desc( sprintf('Type of project: %s', join(', ', Finishing::Project::Utils->project_types)) );
my %src :name(src:r)
    :type(in_list)
    :options([ Finishing::Project::Utils->contig_sources ])
    :clo('src=s')
    :desc('Source of projects contigs: ');
my %inc_proj_in_ctg :name(inc_proj_in_ctg:o)
    :default(0)
    :clo('inc-proj-in-ctg')
    :desc('This will include the project name in each of the project\'s contig names');
my %ace_src :name(ace_src:o) 
    :type(string)
    :clo('ace-src=s')
    :desc('Ace file pattern, will replace \'[]\' with contig acefile lookup number');
my %ctg_pattern :name(pattern:o)
    :type(string)
    :default('(Contig\d+(\.\d+)?)')
    :clo('ctg-pattern=s')
    :desc('Pattern to parse for contigs');

sub utils : PRIVATE
{
    return Finishing::Project::Utils->instance;
}

sub execute : PRIVATE
{
    my $self = shift;

    my $file = $self->source_file;

    my $seqio = Bio::SeqIO->new('-file' => $file, '-format' => 'Fasta');

    $self->fatal_msg("Could not create Bio::SeqIO for file ($file)")
        and return unless $seqio;

    while ( my $seq = $seqio->next_seq )
    {
        my %proj =
        (
            name => $self->namer->next_name,
            type => $self->type, 
        )
            or return;

        my $pattern = $self->pattern;

        my $ctg_namer = Finishing::Project::Namer->new
        (
            base_name => sprintf
            (
                '%sContig',
                ( $self->include_proj_in_ctg ) ? $proj{name} : '' 
            ),
        );

        foreach my $ctg ( $seq->id =~ /$pattern/g ) #(Contig\d+\.\d+)
        {
            my $src;
            if ( $self->ace_src )
            {
                my $acenum = Finishing::Project::Utils->instance->contig_lookup_number($ctg)
                    or return;
                my $ace = $self->ace_src;
                $ace =~ s/\[\]/$acenum/;
                $src = "$ace=$ctg";
            }
            else 
            {
                $src = $ctg;
            }

            push @{ $proj{ctgs} }, 
            {
                name => $ctg_namer->next_name,
                src => $src,
            };
        }

        $self->writer->write_one(\%proj)
            or return;
    }

    return 1;
}

1;

