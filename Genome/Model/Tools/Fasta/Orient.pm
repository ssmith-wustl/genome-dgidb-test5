package Genome::Model::Tools::Fasta::Orient;

use strict;
use warnings;

use Genome;

require Bio::SearchIO;
require Bio::Seq;
require Bio::SeqIO;
require Bio::Seq::PrimaryQual;
use Data::Dumper;
require File::Temp;
require Genome::Model::Tools::WuBlast::Blastn;
require Genome::Model::Tools::WuBlast::Xdformat::Create;
require IO::File;

my @SENSE_TYPES = (qw/ sense anti_sense /);

class Genome::Model::Tools::Fasta::Orient {
    is  => 'Genome::Model::Tools::Fasta',
    has_optional => [	 
    map(
        {
            $_.'_fasta_file' => {
                is => 'String',
                is_input => 1,
                doc => ucfirst( join('-', split(/_/, $_)) ).' FASTA file',
            }
        } @SENSE_TYPES
    ),
    ],
};

sub oriented_fasta_file {
    return $_[0]->fasta_file_with_new_suffix('oriented');
}

sub oriented_qual_file {
    return $_[0]->qual_file_with_new_suffix('oriented');
}

sub help_brief {
    return 'Orients FASTA (and Quality) files by given sense and anti-sense sequences';
}

sub help_detail { 
    return <<EOS 
    Orients a fasta.
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->sense_fasta_file or $self->anti_sense_fasta_file ) {
        $self->error_message("Need sense or anti-sense fasta files to query");
        return;
    }

    for my $sense_type ( @SENSE_TYPES ) {
        my $fasta_method = $sense_type.'_fasta_file';
        if ( $self->$fasta_method and !-e $self->$fasta_method ) {
            $self->error_message( sprintf("$sense_type FASTA file (%s) does not exist.", $self->$fasta_method) );
            return;
        }
    }

    return $self;
}

sub execute {
    my $self = shift;

    # Temp dir and files
    my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
    my $database = sprintf('%s/blast_db', $tmp_dir);
    my $query_file = sprintf('%s/query_file.fasta', $tmp_dir);

    # Create blast db
    my $xdformat = Genome::Model::Tools::WuBlast::Xdformat::Create->create(
        database => $database,
        overwrite_db => 1,
        fasta_files => [ $self->fasta_file ],
    )
        or return;
    $xdformat->execute
        or return;

    # Blast & parse
    my %needs_complementing;
    for my $sense_type ( @SENSE_TYPES ) {
        my $fasta_method = $sense_type.'_fasta_file';

        next unless defined $self->$fasta_method;
        
        my $blastn = Genome::Model::Tools::WuBlast::Blastn->create(
            database => $database,
            query_file => $self->$fasta_method, 
            M => 1, # these params optimized for sort sequences.
            N => -3,
            Q => 3,
            R => 1,
            V => 100000,
            B => 100000,
        )
            or return;
        $blastn->execute
            or return;

        my $search_io = Bio::SearchIO->new(
            '-file' => $blastn->output_file,
            '-format' => 'blast',
        );

        while ( my $result = $search_io->next_result ) {
            while( my $hit = $result->next_hit ) {
                while ( my $hsp = $hit->next_hsp ){
                    my $query = $hsp->query;
                    my $needs_complementing = 0;
                    if ( $sense_type eq 'sense' ) {
                        # If this hit is on the - strand, it needs to complemeted
                        $needs_complementing = 1 if $query->strand == -1;
                    }
                    else { #anti sense
                        # If this hit is on the + strand, it needs to complemeted
                        $needs_complementing = 1 if $query->strand == 1;
                    }
                    #my $subject_id = $hsp->subject->seq_id;
                    # TODO Verify?
                    # if ( exists $needs_complementing{$subject_id}
                    #        and $needs_complementing{$subject_id} != $needs_complementing ) {
                    #    $self->error_message();
                    #}
                    $needs_complementing{ $hsp->subject->seq_id } = $needs_complementing;
                    #last; # TODO which one to last?
                }
            }
        }

        unlink $blastn->output_file if -e $blastn->output_file;
    }

    # Write FASTA nad Qual
    $self->_write_oriented_fasta_file(\%needs_complementing);
    $self->_write_oriented_qual_file(\%needs_complementing) if $self->have_qual_file;

    $self->status_message( sprintf("Oriented FASTA file is:\n%s\n", $self->oriented_fasta_file) );

    return 1;
}

sub _write_oriented_fasta_file {
    my ($self, $needs_complementing) = @_;

    # Open fasta reading 
    my $bioseq_in = $self->get_fasta_reader( $self->fasta_file )
        or return;
    # Open fasta writing 
    my $oriented_fasta = $self->oriented_fasta_file;
    unlink $oriented_fasta if -e $oriented_fasta;
    my $bioseq_out = $self->get_fasta_writer($oriented_fasta)
        or return;

    while ( my $bioseq = $bioseq_in->next_seq ) { 
        if ( $needs_complementing->{ $bioseq->id } ) {
            $bioseq = $bioseq->revcom;
        }
        $bioseq_out->write_seq($bioseq);
    }

    return 1;
}

sub _write_oriented_qual_file {
    my ($self, $needs_complementing) = @_;

    # Open qual reading 
    my $bioseq_in = $self->get_qual_reader( $self->qual_file )
        or return;
    # Open qual reading 
    my $oriented_qual = $self->oriented_qual_file;
    unlink $oriented_qual if -e $oriented_qual;
    my $bioseq_out = $self->get_qual_writer($oriented_qual)
        or return;

    while ( my $bioseq = $bioseq_in->next_seq ) { 
        if ( $needs_complementing->{ $bioseq->id } ) {
            $bioseq = $bioseq->revcom;
        }
        $bioseq_out->write_seq($bioseq);
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
