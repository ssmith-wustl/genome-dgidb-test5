package Genome::Model::Build::AmpliconAssembly::Amplicon;

use strict;
use warnings;

use Bio::Seq::Quality;
use Carp 'confess';
use Data::Dumper 'Dumper';
use File::Grep 'fgrep';
require Genome::Utility::MetagenomicClassifier::SequenceClassification;
require Finishing::Assembly::Factory;
use Storable;

sub new {
    my ($class, %params) = @_;

    my $self = bless \%params, $class;

    for my $attr (qw/ name directory reads /) {
        $self->_fatal_msg("Attribute ($attr) is required") unless exists $self->{$attr};
    }

    Genome::Utility::FileSystem->validate_existing_directory($self->{directory})
        or confess;

    return $self;
}

sub _fatal_msg {
    my ($self, $msg) = @_;

    confess ref($self)." - ERROR: $msg\n";
}

#< Basic Accessors >#
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

#< Files >#
# name.fasta
# name.fasta.preclip
# name.fasta.view
# name.fasta.ace  
# name.fasta.prescreen
# name.phds
# name.fasta.contigs 
# name.fasta.problems
# name.reads.fasta
# name.fasta.contigs.qual
# name.fasta.problems.qual
# name.reads.fasta.qual
# name.fasta.log  
# name.fasta.qual  
# name.scfs
# name.fasta.memlog 
# name.fasta.qual.preclip
# name.fasta.phrap.out
# name.fasta.singlets
sub _file {
    return $_[0]->get_directory.'/'.$_[0]->get_name.'.'.$_[1];
}

#< Cleanup >#
sub remove_unneeded_files {
    my $self = shift;

    my @unneeded_file_exts = (qw/
        fasta.view fasta.log fasta.singlets
        fasta.problems fasta.problems.qual
        fasta.phrap.out fasta.memlog
        fasta.preclip fasta.qual.preclip 
        fasta.prescreen fasta.qual.prescreen
        scfs phds
        /);
    for my $ext ( @unneeded_file_exts ) {
        my $file = $self->_file($ext);
        #print "$file\n";
        unlink $file if -e $file;
    }

    return 1;
}

#< Aux Files #>
sub scfs_file { # .scfs
    return _file($_[0], 'scfs');
}

sub create_scfs_file {
    my $self = shift;

    my $scfs_file = $self->scfs_file;
    unlink $scfs_file if -e $scfs_file;
    my $scfs_fh = Genome::Utility::FileSystem->open_file_for_writing($scfs_file)
        or return;
    for my $scf ( @{$self->get_reads} ) { 
        $scfs_fh->print("$scf\n");
    }
    $scfs_fh->close;

    if ( -s $scfs_file ) {
        return $scfs_file;
    }
    else {
        unlink $scfs_file;
        return;
    }
}

sub phds_file { # .phds
    return $_[0]->_file('phds');
}

sub classification_file {
    return $_[0]->_file('classification.stor');
}

#< Sequence/Qual Files >#
sub fasta_file_for_type {
    my ($self, $type) = @_;
    my $method = $type.'_fasta_file';
    return $self->$method;
}

sub qual_file_for_type {
    my ($self, $type) = @_;
    my $method = $type.'_qual_file';
    return $self->$method;
}

sub reads_fasta_file { # .fasta - after phred
    return $_[0]->_file('reads.fasta');
}

sub reads_qual_file { # .fasta.qual - after phred
    return $_[0]->_file('reads.fasta.qual');
}

sub processed_fasta_file { # processed.fasta - after screen and trim
    return $_[0]->_file('fasta');
    #return $_[0]->_file('processed.fasta');
}

sub processed_qual_file { # processed.fasta.qual - after screen and trim
    return $_[0]->_file('fasta.qual');
    #return $_[0]->_file('processed.fasta.qual');
}

sub assembly_fasta_file { return contigs_fasta_file(@_); }
sub contigs_fasta_file { # .fasta.contigs - fasta file of assembly 
    return $_[0]->_file('fasta.contigs');
}

sub assembly_qual_file { return contigs_qual_file(@_); }
sub contigs_qual_file { # .fasta.contigs.qual - qual file of assembly
    return $_[0]->_file('fasta.contigs.qual');
}

sub ace_file { # .fasta.ace - ce file from phrap
    return $_[0]->_file('fasta.ace');
}

sub oriented_fasta_file { # .oriented.fasta - post assembly, then oriented
    return $_[0]->_file('oriented.fasta');
}

sub oriented_qual_file { # .oriented.fasta.qual - post assembly, then oriented
    return $_[0]->_file('oriented.fasta.qual');
}

#< Assembled Sequence/Qual and Info >#
sub get_bioseq { 
    return $_[0]->_get_bioseq_info->{bioseq};
}

sub get_bioseq_source {
    return $_[0]->_get_bioseq_info->{source};
}

sub get_assembled_reads {
    return $_[0]->_get_bioseq_info->{assembled_reads};
}

sub get_assembled_read_count {
    return scalar(@{$_[0]->get_assembled_reads});
}

sub was_assembled_successfully {
    return ( @{$_[0]->get_assembled_reads} ) ? 1 : 0;
}

sub is_bioseq_oriented {
    return $_[0]->_get_bioseq_info->{oriented};
}

sub _get_bioseq_info {
    my $self = shift;

    unless ( $self->{_bioseq_info} ) {
        my %info;
        for my $method (qw/ 
            _get_bioseq_info_from_oriented_fasta _get_bioseq_info_from_longest_contig
            _get_bioseq_info_from_longest_read _get_bioseq_info_from_nothing 
            /) {
            %info = $self->$method;
            last if %info;
        }

        # Set bioseq props
        if ( $info{bioseq} ) {
            $info{bioseq}->id( $self->get_name );
            $info{bioseq}->desc(
                sprintf(
                    'source=%s reads=%s',
                    $info{source},
                    ( join(',', @{$info{assembled_reads}}) || '' ),
                )
            );
            $info{bioseq}->force_flush(1);
        }

        $self->{_bioseq_info} = \%info;
    }

    return $self->{_bioseq_info};
}

sub confirm_orientation {
    my ($self, $complement) = @_;

    my $bioseq = $self->get_bioseq;
    return unless $bioseq;

    if ( $complement ) {
        my $revcom_bioseq = $bioseq->revcom;
        unless ( $revcom_bioseq ) {
            $self->_fatal_msg("Can't reverse complement bioseq");
        }
        $bioseq = $revcom_bioseq;
    }

    my $fasta_file = $self->oriented_fasta_file;
    unlink $fasta_file if -e $fasta_file;
    my $fasta_o = Bio::SeqIO->new(
        '-format' => 'fasta',
        '-file' => "> $fasta_file",
    )
        or $self->_fatal_msg("Can't open fasta file ($fasta_file)");
    $fasta_o->write_seq($bioseq);

    my $qual_file = $self->oriented_qual_file;
    unlink $qual_file if -e $qual_file;
    my $qual_o = Bio::SeqIO->new(
        '-format' => 'qual',
        '-file' => "> $qual_file",
    )
        or $self->_fatal_msg("Can't open qual file ($qual_file)");
    $qual_o->write_seq($bioseq);

    $self->{_bioseq_info}->{bioseq} = $bioseq;
    $self->{_bioseq_info}->{oriented} = 1;
    
    return 1;
}
    
sub _get_bioseq_info_from_oriented_fasta {
    my $self = shift;

    # Fasta
    my $fasta_file = $self->oriented_fasta_file;
    return unless -s $fasta_file;
    my $fasta_reader = Bio::SeqIO->new(
        '-file' => "< $fasta_file",
        '-format' => 'fasta',
    )
        or return;
    my $fasta = $fasta_reader->next_seq
        or return;

    my ($source_string) = $fasta->desc =~ /source=([\w]+)/;
    # TODO error if no source string?

    my ($read_string) = $fasta->desc =~ /reads=([\w\d\.\-\_])+/;
    # TODO error if no read string?
    my @reads = split(',', $read_string);
    #print Dumper([$self->get_name, $fasta->desc, \@reads]);
    
    # Qual
    my $qual_file = $self->oriented_qual_file;
    my $qual_reader = Bio::SeqIO->new(
        '-file' => "< $qual_file",
        '-format' => 'qual',
    )
        or return;
    my $qual = $qual_reader->next_seq
        or return;

    return (
        bioseq => Bio::Seq::Quality->new(
            '-seq' => $fasta->seq,
            '-qual' => $qual->qual,
        ), 
        assembled_reads => \@reads,
        source => $source_string,
        oriented => 1,
    );
}

sub _get_bioseq_info_from_longest_contig {
    my $self = shift;

    return unless -s sprintf('%s/%s.fasta.contigs', $self->get_directory, $self->get_name);
    my $acefile = sprintf('%s/%s.fasta.ace', $self->get_directory, $self->get_name);
    my $factory = Finishing::Assembly::Factory->connect('ace', $acefile);
    my $contigs = $factory->get_assembly->contigs;
    my $contig = $contigs->next
        or return;
    while ( my $ctg = $contigs->next ) {
        next unless $ctg->reads->count > 1;
        $contig = $ctg if $ctg->unpadded_length > $contig->unpadded_length;
    }
    # Reads
    my $reads = $contig->reads;
    return unless $reads->count > 1;
    my $read_names = [ sort { $a cmp $b } map { $_->name } $reads->all ];

    #my $reads_attempted = fgrep { /phd/ } sprintf('%s/%s.phds', $self->get_directory, $self->get_name); unless ( $reads_attempted ) { $self->error_message( sprintf('No attempted reads in phds file (%s/%s.phds)', $self->get_directory, $self->get_name)); return; }

    # Bioseq
    my $bioseq = Bio::Seq::Quality->new(
        '-seq' => $contig->unpadded_base_string,
        '-qual' => join(' ', @{$contig->qualities}),
    );

    $factory->disconnect;

    return (
        bioseq => $bioseq,
        assembled_reads => $read_names,
        source => 'assembly',
        oriented => 0,
    );
}

sub _get_bioseq_info_from_longest_read {
    my $self = shift;

    # Fasta
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

    # Qual
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

    return (
        bioseq => Bio::Seq::Quality->new(
            '-seq' => $longest_fasta->seq,
            '-qual' => $longest_qual->qual,
        ),
        assembled_reads => [],
        source => 'read',
        oriented => 0,
    );
}

sub _get_bioseq_info_from_nothing {
    my $self = shift;

    return (
        bioseq => undef,
        assembled_reads => [],
        source => 'read',
        oriented => 0,
    );
}

#< Classification >#
sub get_classification {
    my $self = shift;

    my $classification_file = $self->classification_file;
    return unless -s $classification_file;

    return retrieve($classification_file);
}

sub save_classification {
    my ($self, $classification) = @_;

    my $classification_file = $self->classification_file;
    unlink $classification_file if -e $classification_file;
    store($classification, $classification_file);
    
    return 1;
}

1;

#$HeadURL$
#$Id$
