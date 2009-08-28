package Genome::AmpliconAssembly;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require File::Copy;
require Genome::Consed::Directory;
require Genome::AmpliconAssembly::Amplicon;

my %ATTRIBUTES = (
    directory => {
        is => 'Text',
        doc => 'Base directory',
    },
    sequencing_center => {
        is => 'Text',
        is_optional => 1,
        default_value => __PACKAGE__->default_sequencing_center,
        doc => 'Sequencing Center that the amplicons were sequenced.  Currently supported centers: '.join(', ', __PACKAGE__->valid_sequencing_centers).' (default: '.__PACKAGE__->default_sequencing_center.').',
    },
    sequencing_platform => {
        is => 'Text',
        is_optional => 1,
        default_value => __PACKAGE__->default_sequencing_platform,
        doc => 'Platform upon whence the amplicons were sequenced.  Currently supported platforms: '.join(', ', __PACKAGE__->valid_sequencing_platforms).' (default: '.__PACKAGE__->default_sequencing_platform.').',
    },
    assembler => {
        is => 'Text',
        is_optional => 1,
        default_value => __PACKAGE__->default_assembler,
        doc => 'The assembler to use.  Currently supported assemblers: '.join(', ', valid_assemblers()).' (default: '.__PACKAGE__->default_assembler.').',
    },
    assembly_size => { # amplicon_size
        is => 'Integer',
        is_optional => 1,
        doc => 'Expected assembly size for an assembled amplicon.',
    },
    subject_name => {
        is => 'Text',
        is_optional => 1,
        doc => 'The subject name of the underlying data.  Used primarily in naming files (etc) that represent the entire amplicon assembly, like an assembled fasta of each amplicon.',
    },
);

#< UR >#
class Genome::AmpliconAssembly {
    is => 'UR::Object',
    has => [ %ATTRIBUTES ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( Genome::Utility::FileSystem->validate_existing_directory( $self->directory ) ) {
        $self->delete;
        return;
    }

    for my $attribute (qw/ sequencing_platform sequencing_center assembler /) {
        unless ( $self->validate_attribute_value($attribute) ) {
            $self->delete;
            return;
        }
    }

    $self->create_directory_structure
        or return;

    return $self;
}

#< Atributes >#
sub attributes {
    return %ATTRIBUTES;
}

sub attribute_names {
    return keys %ATTRIBUTES;
}

sub get_attribute_for_name {
    my ($class, $name) = @_;

    confess "No attribute name given to get attribute" unless $name;
    confess "No attribute found for name ($name)" unless exists $ATTRIBUTES{$name};

    return $ATTRIBUTES{$name};
}

sub helpful_methods {
    return (qw/ 
        chromat_dir phd_dir edit_dir
        consed_directory create_directory_structure
        get_amplicons 
        amplicon_fasta_types amplicon_bioseq_method_for_type
        fasta_file_for_type qual_file_for_type
        assembly_fasta reads_fasta processed_fasta 
        /);
}

sub validate_attribute_value {
    my ($self, $attribute) = @_;

    my $value = $self->$attribute;
    unless ( defined $value ) { # all attrs have defaults, make sure it is set
        $self->error_message("No value for $attribute given");
        return;
    }
    
    my $valid_values_method = 'valid_'.$attribute.'s';
    unless ( grep { $value eq $_ } $self->$valid_values_method ) {
        $self->error_message(
            sprintf(
                'Invalid %s %s. Valid %ss: %s',
                $attribute,
                $value,
                $attribute,
                join(', ',valid_sequencing_centers()),
            )
        );
        return;
    }

    return 1;
}

# Sequencing Centers
sub valid_sequencing_centers {
    return (qw/ gsc broad /);
}

sub default_sequencing_center {
    return (valid_sequencing_centers)[0];
}

# Sequencing Platforms
sub valid_sequencing_platforms {
    return (qw/ sanger /);
}

sub default_sequencing_platform {
    return (valid_sequencing_platforms)[0];
}

# Assemblers
sub valid_assemblers {
    return (qw/ phredphrap /);
}

sub default_assembler {
    return (valid_assemblers)[0];
}

#< DIRS >#
sub consed_directory {
    my $self = shift;

    unless ( $self->{_consed_directory} ) {
        $self->{_consed_directory} = Genome::Consed::Directory->create(directory => $self->directory);
    }

    return $self->{_consed_directory};
}

sub create_directory_structure {
    my $self = shift;

    $self->consed_directory->create_extended_directory_structure
        or return;

    return 1;
}

sub edit_dir {
    return $_[0]->consed_directory->edit_dir;
}
    
sub phd_dir {
    return $_[0]->consed_directory->phd_dir;
}
    
sub chromat_dir {
    return $_[0]->consed_directory->chromat_dir;
}

sub fasta_dir {
    return $_[0]->consed_directory->fasta_dir;
}

#< FASTA >#
my %_fastas_and_amplicon_bioseq_methods = (
    reads => 'get_bioseqs_for_raw_reads',
    processed => 'get_bioseqs_for_processed_reads',
    assembly => 'get_assembly_bioseq',
    oriented => 'get_oriented_bioseq',
);

sub amplicon_fasta_types {
    return keys %_fastas_and_amplicon_bioseq_methods;
}

sub amplicon_bioseq_method_for_type {
    return $_fastas_and_amplicon_bioseq_methods{$_[1]};
}

sub fasta_file_for_type {
    my ($self, $type) = @_;

    return sprintf(
        '%s/%s%s.fasta',
        $self->fasta_dir,
        ( defined $self->subject_name ? $self->subject_name.'.' : '' ),
        $type,
    );
}

sub qual_file_for_type {
    return $_[0]->fasta_file_for_type($_[1]).'.qual';
}

#< Amplicons >#
sub get_amplicons {
    my $self = shift;

    my $method = sprintf(
        '_get_amplicons_and_read_names_for_%s_%s', 
        $self->sequencing_center,
        $self->sequencing_platform,
    );
    my $amplicons = $self->$method;
    unless ( $amplicons and %$amplicons ) {
        $self->error_message(
            sprintf('No amplicons found in chromat_dir of directory (%s)', $self->directory) 
        );
        return;
    }

    my @amplicons;
    my $edit_dir = $self->edit_dir;
    for my $name ( keys %$amplicons ) {
        push @amplicons, Genome::AmpliconAssembly::Amplicon->create(
            name => $name,
            reads => $amplicons->{$name},
            directory => $edit_dir,
        );
    }

    return \@amplicons;
}

sub _get_amplicons_and_read_names_for_gsc_sanger {
    my $self = shift;

    my $dh = Genome::Utility::FileSystem->open_directory( $self->chromat_dir )
        or return;

    my %amplicons;
    while ( my $read_name = $dh->read ) {
        next if $read_name =~ m#^\.#;
        $read_name =~ s#\.gz##;
        my $amplicon_name = $self->_get_amplicon_name_for_gsc_sanger_read_name($read_name)
            or next;
        push @{$amplicons{$amplicon_name}}, $read_name;
    }
    $dh->close;

    return \%amplicons;
}

sub _get_amplicons_and_read_names_for_broad_sanger {
    my $self = shift;

    my $dh = Genome::Utility::FileSystem->open_directory( $self->chromat_dir )
        or return;

    my %amplicons;
    while ( my $read_name = $dh->read ) {
        next if $read_name =~ m#^\.#;
        $read_name =~ s#\.gz$##;
        my $amplicon = $self->_get_amplicon_name_for_broad_sanger_read_name($read_name)
            or return;
        push @{$amplicons{$amplicon}}, $read_name;
    }
    
    return  \%amplicons;
}

#< Amplicon Reads >#
sub get_method_for_get_amplicon_name_for_read_name {
    my $self = shift;

    return sprintf(
        '_get_amplicon_name_for_%s_%s_read_name', 
        $self->sequencing_center,
        $self->sequencing_platform,
    );
}

sub _get_amplicon_name_for_gsc_sanger_read_name {
    my ($self, $read_name) = @_;
    
    $read_name =~ /^(.+)\.[bg]\d+$/
        or return;

    return $1;
}

sub _get_amplicon_name_for_broad_sanger_read_name {
    my ($self, $read_name) = @_;

    $read_name =~ s#\.T\d+$##;
    $read_name =~ s#[FR](\w\d\d?)$#\_$1#; # or next;

    return $read_name;
}

sub get_all_amplicons_reads_for_read_name {
    my ($self, $read_name) = @_;

    unless ( $read_name ) {
        $self->error_message("No read name given to get all reads for amplicon.");
        return;
    }

    my $amp_method = $self->get_method_for_get_amplicon_name_for_read_name;
    my $amplicon_name = $self->$amp_method($read_name);
    unless ( $amplicon_name ) {
        $self->error_message("Can't get amplicon name for read name ($read_name)");
        return;
    }

    my $reads_method = $self->get_method_for_get_all_amplicons_reads_for_read_name;
    my @read_names = $self->$reads_method($amplicon_name);
    unless ( @read_names ) {
        $self->error_message("No reads found for amplicon name ($amplicon_name)");
        return;
    }

    
    return @read_names;
}

sub get_method_for_get_all_amplicons_reads_for_read_name {
    sprintf(
        '_get_all_reads_for_%s_%s_amplicon',
        $_[0]->sequencing_center,
        $_[0]->sequencing_platform,
    );
}

sub _get_all_reads_for_gsc_sanger_amplicon {
    my ($self, $amplicon_name) = @_;
    
    my $chromat_dir = $self->chromat_dir;
    my @read_names;
    for my $read_name ( glob("$chromat_dir/$amplicon_name.*") ) {
        $read_name =~ s#$chromat_dir/##;
        $read_name =~ s#\.gz##;
        push @read_names, $read_name;
    }

    return @read_names;
}

sub _get_all_reads_for_broad_sanger_amplicon {
    die "Not implemented\n";
}

#< Contamination Screening >#
sub contamination_dir {
    return $_[0]->directory.'/contamination';
}

sub contamination_reads_dir {
    return $_[0]->contamination_dir.'/reads';
}
    
sub amplicon_fasta_file_for_contamination_screening {
    return $_[0]->contamination_dir.'/amplicon_reads.fasta';
}

sub create_contamination_dir_structure {
    my $self = shift;

    my $contamination_dir = $self->contamination_dir;
    unless ( -d $contamination_dir ) {
        return unless Genome::Utility::FileSystem->create_directory($contamination_dir);
    }

    my $reads_dir = $self->contamination_reads_dir;
    unless ( -d $reads_dir ) {
        return unless Genome::Utility::FileSystem->create_directory($reads_dir);
    }

    return 1;
}

sub create_amplicon_fasta_file_for_contamination_screening {
    my $self = shift;

    my $amplicons = $self->get_amplicons
        or return;

    $self->create_contamination_dir_structure
        or return;
    
    my $fasta_file = $self->amplicon_fasta_file_for_contamination_screening;
    unlink $fasta_file if -e $fasta_file;
    my $fasta_writer = Bio::SeqIO->new(
        '-file' => '>'.$fasta_file,
        '-fomat' => 'fasta',
    );
    for my $amplicon ( @$amplicons ) {
        for my $bioseq ( $amplicon->get_bioseqs_for_processed_reads ) {
            next unless $bioseq->length >= 11;
            $bioseq->seq( uc $bioseq->seq );
            $fasta_writer->write_seq($bioseq);
        }
    }

    return $fasta_file;
}

sub remove_contaminated_amplicons_by_reads_in_file {
    my ($self, $file) = @_;

    $self->create_contamination_dir_structure
        or return;

    my $fh = Genome::Utility::FileSystem->open_file_for_reading($file)
        or return;

    my %amplicons_seen;
    my $chromat_dir = $self->chromat_dir;
    my $contamination_reads_dir = $self->contamination_reads_dir;
    my $amp_method = $self->get_method_for_get_amplicon_name_for_read_name;
    my $reads_method = $self->get_method_for_get_all_amplicons_reads_for_read_name;

    while ( my $read_name = $fh->getline ) {
        chomp $read_name;
        my $amplicon_name = $self->$amp_method($read_name);
        unless ( $amplicon_name ) {
            $self->error_message("Can't get amplicon name for read name ($read_name)");
            return;
        }
        my @read_names = $self->$reads_method($amplicon_name);
        unless ( @read_names ) {
            $self->error_message("Can't get reads for amplicon name ($amplicon_name)");
            return;
        }
        # Move chromats - this effectively removes the amplicon
        # TODO create the amplicon interface here, to support sanger and 454
        #  maybe move this logic to amplicon?
        for my $read_name ( @read_names ) {
            my $from = "$chromat_dir/$read_name.gz"; 
            my $to = "$contamination_reads_dir/$read_name.gz";
            unless ( -e $from ) { # ok, i guess
                $self->error_message("Can't find trace $read_name");
                next;
            }
            unless ( File::Copy::move($from, $to) ) { # not ok
                $self->error_message("Can't move $from to $to\: $!");
                return;
            }
        }
        # TODO move phd_dir edit_dir files?
    }

    return 1;
}

1;

=pod

=head1 Name

Genome::AmpliconAssembly

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 valid_sequencing_centers

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 default_sequencing_center

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 consed_directory

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 create_directory_structure

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 edit_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 phd_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 chromat_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 fasta_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 amplicon_fasta_types

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 amplicon_bioseq_method_for_type

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 fasta_file_for_type

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 qual_file_for_type

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 get_amplicons

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 contamination_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 contamination_reads_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 amplicon_fasta_file_for_contamination_screening

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 create_contamination_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 create_amplicon_fasta_files_for_contamination_screening

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 read_is_contaminated

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2009 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$

