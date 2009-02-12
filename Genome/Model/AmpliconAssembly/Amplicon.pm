package Genome::Model::AmpliconAssembly::Amplicon;

use strict;
use warnings;

use Bio::Seq::Quality;
use Carp 'confess';
use Data::Dumper 'Dumper';
use File::Grep 'fgrep';
require Finishing::Assembly::Factory;
require Genome::Utility::FileSystem;

sub new {
    my ($class, %params) = @_;

    my $self = bless {
        _is_built => 0,
        _assembled_reads => [],
    },
    $class;

    for my $attr (qw/ name directory reads /) {
        $self->_fatal_msg("Attribute ($attr) is required") unless exists $params{$attr};
        $self->{$attr} = delete $params{$attr};
    }

    Genome::Utility::FileSystem->validate_existing_directory($self->{directory})
        or confess;

    return $self;
}

sub _fatal_msg {
    my ($self, $msg) = @_;

    confess ref($self)." - ERROR: $msg\n";
}

sub get_name {
    return $_[0]->{name};
}

sub get_directory {
    return $_[0]->{directory};
}

sub get_reads {
    return $_[0]->{reads};
}

sub get_read_count {
    return scalar(@{$_[0]->get_reads});
}

sub build {
    my $self = shift;

    if ( -s sprintf('%s/%s.fasta.contigs', $self->get_directory, $self->get_name) ) {
        $self->_build_bioseq_from_longest_contig;
    }
    else {
        $self->_build_bioseq_from_longest_read;
    }

    $self->{_is_built} = 1;

    return 1;
}

sub is_built {
    return $_[0]->{_is_built};
}

sub was_assembled_successfully {
    my $self = shift;

    return ( @{$self->get_assembled_reads} ) ? 1 : 0;
}

sub get_assembled_reads {
    my $self = shift;

    $self->build unless $self->is_built;

    return $self->{_assembled_reads}
}

sub get_assembled_read_count {
    return scalar(@{$_[0]->get_assembled_reads});
}

sub get_bioseq {
    my $self = shift;

    $self->build unless $self->is_built;

    return $self->{_bioseq}; # There may not be a bioseq...
}

sub _build_bioseq_from_longest_contig {
    my $self = shift;

    #< Determine longest contig >#
    my $acefile = sprintf('%s/%s.fasta.ace', $self->get_directory, $self->get_name);
    my $factory = Finishing::Assembly::Factory->connect('ace', $acefile);
    my $contigs = $factory->get_assembly->contigs;
    my $contig = $contigs->next
        or return;
    while ( my $ctg = $contigs->next ) {
        next unless $ctg->reads->count > 1;
        $contig = $ctg if $ctg->unpadded_length > $contig->unpadded_length;
    }
    my $reads = $contig->reads;
    return unless $reads->count > 1;
    $self->{_assembled_reads} = [ sort { $a cmp $b } map { $_->name } $reads->all ];

    #my $reads_attempted = fgrep { /phd/ } sprintf('%s/%s.phds', $self->get_directory, $self->get_name); unless ( $reads_attempted ) { $self->error_message( sprintf('No attempted reads in phds file (%s/%s.phds)', $self->get_directory, $self->get_name)); return; }

    $self->{_bioseq} = Bio::Seq::Quality->new(
        '-id' => $self->get_name,
        '-desc' => sprintf('source=contig reads=%s', $reads->count), 
        '-seq' => $contig->unpadded_base_string,
        '-qual' => join(' ', @{$contig->qualities}),
    );

    $factory->disconnect;

    return 1;
}

sub _build_bioseq_from_longest_read {
    my $self = shift;

    #< Fasta
    my $fasta_file = sprintf('%s/%s.fasta', $self->get_directory, $self->get_name);
    return unless -s $fasta_file;
    my $fasta_reader = Bio::SeqIO->new(
        '-file' => $fasta_file,
        '-format' => 'fasta',
    )
        or return;
    my $longest_fasta = $fasta_reader->next_seq;
    while ( my $seq = $fasta_reader->next_seq ) {
        $longest_fasta = $seq if $seq->length > $longest_fasta->length;
    }

    unless ( $longest_fasta ) { # should never happen
        $self->error_message( 
            sprintf(
                'Found fasta file for amplicon (%s) reads, but could not find the longest fasta',
                $self->get_name,
            ) 
        );
        return;
    }

    #< Qual
    my $qual_file = sprintf('%s/%s.fasta.qual', $self->get_directory, $self->get_name);
    my $qual_reader = Bio::SeqIO->new(
        '-file' => $qual_file,
        '-format' => 'qual',
    )
        or return;
    my $longest_qual;
    while ( my $seq = $qual_reader->next_seq ) {
        next unless $seq->id eq $longest_fasta->id;
        $longest_qual = $seq;
        last;
    }

    unless ( $longest_qual ) { # should not happen
        $self->error_message( 
            sprintf(
                'Found largest fasta for amplicon (%s), but could not find corresponding qual with id (%s)',
                $self->get_name,
                $longest_fasta->id,
            ) 
        );
        return;
    }

    $self->{_bioseq} = Bio::Seq::Quality->new(
        '-id' => $self->get_name,
        '-desc' => sprintf('source=%s reads=1', $longest_fasta->id),
        '-seq' => $longest_fasta->seq,
        '-qual' => $longest_qual->qual,
    );

    return 1;
}

1;

#$HeadURL$
#$Id$
