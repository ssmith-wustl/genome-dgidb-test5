package Genome::Model::Build::MetagenomicComposition16s::Sanger;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require File::Copy;
use Finishing::Assembly::Factory;

class Genome::Model::Build::MetagenomicComposition16s::Sanger {
    is => 'Genome::Model::Build::MetagenomicComposition16s',
};

sub calculate_estimated_kb_usage {
    # Each piece of instrument data uses about 30Mb of space. Adjust if more files are removed
    my $self = shift;

    my $instrument_data_count = $self->instrument_data_count;
    unless ( $instrument_data_count ) { # very bad; should be checked when the build is created
        confess("No instrument data found for build ".$self->description);
    }

    return $instrument_data_count * 30000;
}

#< Prepare Inst Data >#
# TODO move here

#< INTR DATA >#
sub link_instrument_data {
    my ($self, $instrument_data) = @_;

    unless ( $instrument_data ) {
        $self->error_message("No instument data to link");
        return;
    }

    my $chromat_dir = $self->chromat_dir;
    my $instrument_data_dir = $instrument_data->resolve_full_path;
    my $dh = Genome::Sys->open_directory($instrument_data_dir)
        or return;

    for (1..2) {  # . and ..
        my $dot_dir = $dh->read;
        confess("Expecting one of the dot directories, but got $dot_dir for ".$self->description) unless $dot_dir =~ /^\.{1,2}$/;
    }
    my $cnt = 0;
    while ( my $trace = $dh->read ) {
        $cnt++;
        my $target = sprintf('%s/%s', $instrument_data_dir, $trace);
        my $link = sprintf('%s/%s', $chromat_dir, $trace);
        next if -e $link; # link points to a target that exists
        unlink $link if -l $link; # remove - link exists, but points to something that does not exist
        Genome::Sys->create_symlink($target, $link)
            or return;
    }

    unless ( $cnt ) {
        $self->error_message("No traces found in instrument data directory ($instrument_data_dir)");
    }

    return $cnt;
}

#< DIRS >#
sub consed_directory {
    my $self = shift;

    unless ( $self->{_consed_directory} ) {
        $self->{_consed_directory} = Genome::Model::Tools::Consed::Directory->create(directory => $self->data_directory);
    }

    return $self->{_consed_directory};
}

sub _sub_dirs {
    return $_[0]->consed_directory->directories;
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

#< Files >#
# raw reads
sub raw_reads_fasta_file {
    return $_[0]->fasta_dir.'/'.$_[0]->file_base_name.'.reads.raw.fasta';
}

sub raw_reads_qual_file {
    return $_[0]->raw_reads_fasta_file.'.qual';
}

# processsed reads
sub processed_reads_fasta_file {
    return $_[0]->fasta_dir.'/'.$_[0]->file_base_name.'.reads.processed.fasta';
}

sub processed_reads_qual_file {
    return $_[0]->processed_reads_fasta_file.'.qual';
}

#< Amplicons >#
sub _amplicon_iterator_for_name {
    my ($self, $set_name) = @_;

    # open chromt_dir
    my $dh = Genome::Sys->open_directory( $self->chromat_dir );
    unless ( $dh ) {
        $self->error_message("Can't open chromat dir to get reads. See above error.");
        return;
    }
    # skip . and ..
    $dh->read; $dh->read;
    # collect the read names
    my @all_read_names;
    while ( my $read_name = $dh->read ) {
        $read_name =~ s#\.gz$##;
        push @all_read_names, $read_name;
    }
    # make sure we got some 
    unless ( @all_read_names ) {
        $self->error_message(
            sprintf(
                "No reads found in chromat dir of build (%s) data directory (%s)",
                $self->id,
                $self->data_directory,
            )
        );
        return;
    }
    #sort
    @all_read_names = sort { $a cmp $b } @all_read_names;

    # Filters - setup
    my @filters;
    if ( $self->processing_profile->only_use_latest_iteration_of_reads ) {
        push @filters, '_remove_old_read_iterations_from_amplicon';
    }
    
    if ( $self->processing_profile->exclude_contaminated_amplicons ) {
        push @filters, '_amplicon_is_not_contaminated';
    }

    my $classification_file = $self->classification_file_for_set_name($set_name);
    my ($classification_io, $classification_line);
    if ( -s $classification_file ) {
        $classification_io = eval{ Genome::Sys->open_file_for_reading($classification_file); };
        if ( not $classification_io ) {
            $self->error_message('Failed to open classification file: '.$classification_file);
            return;
        }
        $classification_line = $classification_io->getline;
        chomp $classification_line;
    }

    my $amplicon_name_for_read_name = '_get_amplicon_name_for_'.$self->sequencing_center
    .'_read_name';
    my $pos = 0;
    return sub{
        AMPLICON: while ( $pos < $#all_read_names ) {
            # Get amplicon name
            my $amplicon_name = $self->$amplicon_name_for_read_name($all_read_names[$pos]);
            unless ( $amplicon_name ) {
                confess sprintf(
                    'Build determine amplicon name for %s read name (%s) for build (%s)',
                    $all_read_names[$pos],
                    $self->sequencing_center,
                    $self->id,
                );
            }
            # Start reads list
            my @read_names = ( $all_read_names[$pos] );
            READS: while ( $pos < $#all_read_names ) {
                # incremnent
                $pos++;
                # Get amplicon name
                my $read_amplicon_name = $self->$amplicon_name_for_read_name($all_read_names[$pos]);
                unless ( $read_amplicon_name ) {
                    confess sprintf(
                        'Could not determine amplicon name for %s read name (%s) for build (%s)',
                        $all_read_names[$pos],
                        $self->sequencing_center,
                        $self->id,
                    );
                }
                unless ( $read_amplicon_name eq $amplicon_name ) { 
                    # go on to filtering
                    last READS; 
                }
                push @read_names, $all_read_names[$pos]; # add read
            }

            # Create amplicon object
            my $amplicon = {
                name => $amplicon_name,
                reads => \@read_names,
            };

            # Filter
            for my $filter ( @filters ) {
                next AMPLICON unless $self->$filter($amplicon);
            }

            # Processed oseq
            $self->load_seq_for_amplicon($amplicon); # dies on error

            return $amplicon if not $classification_line;

            my @classification = split(';', $classification_line); # 0 => id | 1 => ori
            if ( not defined $classification[0] ) {
                Carp::confess('Malformed classification line: '.$classification_line);
            }
            if ( $amplicon->{name} ne $classification[0] ) {
                return $amplicon;
            }

            $classification_line = $classification_io->getline;
            chomp $classification_line if $classification_line;

            $amplicon->{classification} = \@classification;
            return $amplicon;
        }
    };
}

sub _get_amplicon_name_for_gsc_read_name {
    my ($self, $read_name) = @_;

    $read_name =~ /^(.+)\.[bg]\d+$/
        or return;

    return $1;
}

sub _get_amplicon_name_for_broad_read_name {
    my ($self, $read_name) = @_;

    $read_name =~ s#\.T\d+$##;
    $read_name =~ s#[FR](\w\d\d?)$#\_$1#; # or next;

    return $read_name;
}

sub load_seq_for_amplicon {
    my ($self, $amplicon) = @_;

    die "No amplicon to load seq." unless $amplicon;

    # get contig from acefile
    my $acefile = $self->ace_file_for_amplicon($amplicon);
    return unless -s $acefile; # ok
    my $ace = Finishing::Assembly::Factory->connect('ace', $acefile);
    my $assembly = $ace->get_assembly;
    my $contigs = $assembly->contigs;
    my ($contig, $reads);
    while ( $contig = $contigs->next ) {
        # check the length
        next unless $contig->unpadded_length >= $self->amplicon_size;
        # read count
        my $read_iterator = $contig->reads;
        $reads = [ sort { $a cmp $b } map { $_->name } $read_iterator->all ];
        next unless @$reads > 1;
        last;
    }
    return unless $contig; # ok

    my $seq = {
        id => $amplicon->{name},
        seq => $contig->unpadded_base_string,
        qual => join('', map { chr($_ + 33) } @{$contig->qualities}),
    };
    if ( $seq->{seq} !~ /^[ATGCNX]+$/i ) {
        Carp::confess('Illegal caharcters in sequence for amplicon: '.$amplicon->{name}."\n".$seq->{seq}); 
    }

    if ( length $seq->{seq} !=  length $seq->{qual} ) {
        Carp::confess('Unequal lengths of sequence and quality for amplicon: '.$amplicon->{name}."\n".$seq->{seq}."\n".$seq->{qual});
    }

    $amplicon->{seq} = $seq;
    $amplicon->{reads_processed} = $reads;

    $ace->disconnect;
    
    return $seq;
}

sub _remove_old_read_iterations_from_amplicon {
    my ($self, $amplicon) = @_;

    my %reads;
    for my $read_name ( @{$amplicon->{reads}} ) {
        my $read = GSC::Sequence::Read->get(trace_name => $read_name);
        confess "Can't get GSC read ($read_name). This is required to remove old read iterations from an amplicon." unless $read;

        my $read_id = $amplicon->{name}.$read->primer_code;
        if ( exists $reads{$read_id} ) {
            my $date_compare = UR::Time->compare_dates(
                '00:00:00 '.$read->run_date,
                '00:00:00 '.$reads{$read_id}->run_date,
            ); #returns -1, 0, or 1
            #print "RUN DATE $read_name => ".$read->run_date."($date_compare)\n";
            $reads{$read_id} = $read if $date_compare eq 1;
        }
        else {
            $reads{$read_id} = $read;
        }
    }

    $amplicon->{reads} = [
        sort { 
            $a cmp $b 
        } map { 
            $_->trace_name 
        } values %reads 
    ];

    return 1;
}

sub _amplicon_is_not_contaminated {
    my ($self, $amplicon) = @_;

    for my $read_name ( @{$amplicon->{reads}} ) {
        my $read = GSC::Sequence::Read->get(trace_name => $read_name);
        confess "Can't get GSC read ($read_name). This is required to check if an amplicon is contaminated." unless $read;
        my $screen_reads_stat = $read->get_screen_read_stat_hmp;
        if ( $screen_reads_stat and $screen_reads_stat->is_contaminated ) {
            return;
        }
    }

    return 1;
}

sub _get_gsc_sequence_read { # in sub to overload on test
    return GSC::Sequence::Read->get(trace_name => $_[1]);
}

#< Amplicon Files >#
sub scfs_file_for_amplicon {
    my ($self, $amplicon) = @_;
    return $self->edit_dir.'/'.$amplicon->{name}.'.scfs';
}

sub create_scfs_file_for_amplicon {
    my ($self, $amplicon) = @_;

    my $scfs_file = $self->scfs_file_for_amplicon($amplicon);
    unlink $scfs_file if -e $scfs_file;
    my $scfs_fh = Genome::Sys->open_file_for_writing($scfs_file)
        or return;
    for my $scf ( @{$amplicon->{reads}} ) { 
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

sub phds_file_for_amplicon {
    my ($self, $amplicon) = @_;
    return $self->edit_dir.'/'.$amplicon->{name}.'.phds';
}

sub reads_fasta_file_for_amplicon { 
    my ($self, $amplicon) = @_;
    return $self->edit_dir.'/'.$amplicon->{name}.'.fasta';
}

sub reads_qual_file_for_amplicon {
    return reads_fasta_file_for_amplicon(@_).'.qual';
}

sub ace_file_for_amplicon { 
    my ($self, $amplicon) = @_;
    return $self->edit_dir.'/'.$amplicon->{name}.'.fasta.ace';
}

#< Clean Up >#
sub clean_up {
    my $self = shift;

    return 1;

    my @amplicon_sets = $self->amplicon_sets
        or return;
    
    my @unneeded_file_exts = (qw/
        fasta.contigs fasta.contigs.qual 
        fasta.view fasta.log fasta.singlets
        fasta.problems fasta.problems.qual
        fasta.phrap.out fasta.memlog
        fasta.preclip fasta.qual.preclip 
        fasta.prescreen fasta.qual.prescreen
        scfs phds
        /);

    for my $amplicon_set ( @amplicon_sets ) {
        while ( my $amplicon = $amplicon_set->() ) {
            for my $ext ( @unneeded_file_exts ) {
                my $file = sprintf('%s/%s.%s', $self->edit_dir, $amplicon->{name}, $ext);
                unlink $file if -e $file;
            }
        }
    }

    return 1;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2005 - 2010 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
