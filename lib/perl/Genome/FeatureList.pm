package Genome::FeatureList;

use strict;
use warnings;

use Genome;

class Genome::FeatureList {
    is => 'UR::Object',
    table_name => 'FEATURE_LIST',
    has => [
        id => { is => 'Text', len => 64 },
        name => { is => 'Text', len => 200 },
        format => { is => 'Text', len => 64, doc => 'Indicates whether the file follows the BED spec.', valid_values => ['1-based', 'true-BED', 'multi-tracked', 'multi-tracked 1-based', 'unknown'], },
        file_content_hash => { is => 'Text', len => 32, doc => 'MD5 of the BED file (to ensure integrity' },
        is_multitracked => {
            is => 'Boolean', calculate_from => ['format'],
            calculate => q{ return scalar ($format =~ /multi-tracked/); },
        },
        is_1_based => {
            is => 'Boolean', calculate_from => ['format'],
            calculate => q{ return scalar ($format =~ /1-based/); },
        }
    ],
    has_optional => [
        source => { is => 'Text', len => 64, doc => 'Provenance of this feature list. (e.g. Agilent)', },
        reference_id => { is => 'NUMBER', len => 10, doc => 'ID of the reference sequence build for which the features apply' },
        reference => { is => 'Genome::Model::Build::ImportedReferenceSequence', id_by => 'reference_id' },
        reference_name => { via => 'reference', to => 'name', },
        subject_id => { is => 'NUMBER', len => 10, doc => 'ID of the subject to which the features are relevant' },
        subject => { is => 'Genome::Model::Build', id_by => 'subject_id' },
        disk_allocation   => { is => 'Genome::Disk::Allocation', is_optional => 1, is_many => 1, reverse_as => 'owner', },
        file_path => {
               is => 'Text',
               calculate_from => ['disk_allocation'],
               calculate => q{
                  if($disk_allocation) {
                    my $directory = $disk_allocation->absolute_path;
                       return join('/', $directory, $self->id . '.bed');
                  }
               }
        },

        #TODO This will point to a subclass of Genome::Feature at such point as that class exists.
        content_type => { is => 'VARCHAR2', len => 255, doc => 'The kind of features in the list' },
    ],
    has_optional_transient => [
        #TODO These could be pre-computed and stored in the allocation rather than re-generated every time
        _lims_file_path => {
            is => 'Text',
            doc => 'The path to the temporary dumped copy of the BED file from LIMS',
        },
        _processed_bed_file_path => {
            is => 'Text',
            doc => 'The path to the temporary dumped copy of the post-processed BED file',
        },
        _merged_bed_file_path => {
            is => 'Text',
            doc => 'The path to the temporary dumped copy of the merged post-processed BED file',
        }
    ],
    doc => 'A feature-list is, generically, a set of coördinates for some reference',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    my $self = shift;

    return $self->name . ' (' . $self->id . ')';
}

sub create {
    my $class = shift;
    my %params = @_;

    my $file = delete $params{file_path};
    my $id = delete $params{id};
    $id ||= $class->_next_id;

    my $self = $class->SUPER::create(%params, id => $id);

    if($file and Genome::Sys->check_for_path_existence($file)) {
        my $allocation = Genome::Disk::Allocation->allocate(
            disk_group_name => 'info_apipe_ref',
            allocation_path => 'feature_list/' . $self->id,
            kilobytes_requested => ( int((-s $file) / 1024) + 1),
            owner_class_name => $self->class,
            owner_id => $self->id
        );

        unless ($allocation) {
            $self->delete;
            return;
        }

        my $retval = eval {
            Genome::Sys->copy_file($file, $self->file_path);
        };
        if($@ or not $retval) {
            $self->error_message('Copy failed: ' . ($@ || 'returned' . $retval) );
            $self->delete;
            return;
        }
    }

    #TODO If this is in __errors__, gets called too soon--still would be nice to have
    unless($self->verify_file_md5) {
        $self->error_message('MD5 of copy does not match supplied value!');
        $self->delete;
        return;
    }

    return $self; 
}

#FIXME When a UR::Object has a datasource that is an RDBMS, UR assumes that we want to use a DB sequence to get our
#auto-generated IDs.  This is not the case here, so for now bring back a variation of the default ID generator from
#<UR/Object/Type/InternalAPI.pm>.
#
#Spaces are problematic so they have been replaced.  A few extra sources of numbers have been added to the IDs as well.
sub _next_id {
    my $class = shift;

    my $id_base = $UR::Object::Type::autogenerate_id_base;
    $id_base =~ s/\s/-/g;
    
    my $id = join('-', $id_base, time(), int(9999*rand), ++$UR::Object::Type::autogenerate_id_iter);
    return $id;
}

sub delete {
    my $self = shift;

    #If we commit the delete, need to get rid of the allocation.
    my $upon_delete_callback = $self->_cleanup_allocation_sub;
    $self->create_subscription(method=>'commit', callback=>$upon_delete_callback);

    return $self->SUPER::delete(@_);
}

sub _cleanup_allocation_sub {
    my $self = shift;

    return sub {
        $self->status_message('Now deleting allocation with owner_id = ' . $self->id);
        print $self->status_message;
        my $allocation = $self->disk_allocation;
        if ($allocation) {
            $allocation->deallocate; 
        }
    };
}

sub verify_file_md5 {
    my $self = shift;

    my $bed_file = $self->file_path;

    my $md5_sum = Genome::Sys->md5sum($bed_file);
    if($md5_sum eq $self->file_content_hash) {
        return $md5_sum;
    } else {
        return;
    }
}

#The raw "BED" file we import will be in one many BED-like formats.
#The output of this method is the standardized "true-BED" representation
sub processed_bed_file_content {
    my $self = shift;

    if($self->format eq 'unknown'){
        $self->error_message('Cannot process BED file with unknown format');
        die $self->error_message;
    }

    my $file = $self->file_path;
    unless($self->verify_file_md5) {
        $self->error_message('MD5 mismatch! BED file modified or corrupted?');
        die $self->error_message;
    }

    my $fh = Genome::Sys->open_file_for_reading($file);

    my $print = 1;
    my $bed_file_content;
    my $name_counter = 0;
    while(my $line = <$fh>) {
        chomp($line);
        if($self->is_multitracked) {
            if ($line eq 'track name=tiled_region description="NimbleGen Tiled Regions"') {
                $print = 0;
                next;
            } elsif ($line eq 'track name=target_region description="Target Regions"') {
                $print = 1;
                next;
            }
        }
        if ($print) {
            my @entry = split("\t",$line);
            unless (scalar(@entry) >= 3) {
                $self->error_message('At least three fields are required in BED format files.  Error with line: '. $line);
                die($self->error_message);
            }

            $entry[0] =~ s/chr//g;
            if ($entry[0] =~ /random/) { next; }

            #this is a temporary measure to resolve a support issue.  Will be replaced by more general conversion mechanism
            if ($self->reference_name =~ /^GRCh37-lite/) {
                if($entry[0] =~ /\d+_(GL\d+)R/) {
                    $entry[0] = $1 . '.1';
                } elsif ($entry[0] =~ /Un_gl(\d+)/) {
                    $entry[0] = 'GL' . $1 . '.1';
                }
            }

            # Correct for 1-based start positions in imported BED files,
            # unless at zero already(which means we shouldn't be correcting the position anyway...)
            if ($self->is_1_based) {
                if($entry[1] == 0) {
                    $self->error_message('BED file was imported as 1-based but contains a 0 in the start position!');
                    die($self->error_message);
                }
                $entry[1]--;
            }
            #Bio::DB::Sam slows down dramatically when large names are used, so just number the regions sequentially
            $entry[3] = 'r' . $name_counter++;
            $bed_file_content .= join("\t",@entry) ."\n";
        }
    }
    return $bed_file_content;
}

sub processed_bed_file {
    my $self = shift;

    if($self->format eq 'unknown'){
        $self->error_message('Cannot process BED file with unknown format');
        die $self->error_message;
    }

    unless($self->_processed_bed_file_path) {
        my $content = $self->processed_bed_file_content;
        my $temp_file = Genome::Sys->create_temp_file_path( $self->id . '.processed.bed' );
        Genome::Sys->write_file($temp_file, $content);
        $self->_processed_bed_file_path($temp_file);
    }

    return $self->_processed_bed_file_path;
}

sub merged_bed_file {
    my $self = shift;

    if ($self->format eq 'unknown'){
        $self->error_message('Cannot merge BED file with unknown format');
        die $self->error_message;
    }

    unless($self->_merged_bed_file_path) {
        my $processed_bed_file = $self->processed_bed_file;
        my $temp_file = Genome::Sys->create_temp_file_path( $self->id . '.merged.bed' );

        my %merge_params = (
            input_file => $processed_bed_file,
            output_file => $temp_file,
            report_names => 1,
            #All files should have zero-based start postitions at this point
            maximum_distance => 0,
        );

        my $merge_command = Genome::Model::Tools::BedTools::Merge->create(%merge_params);
        unless($merge_command) {
            $self->error_message('Failed to create merge command.');
            die $self->error_message;
        }
        unless ($merge_command->execute) {
            $self->error_message('Failed to merge BED file with params '. Data::Dumper::Dumper(%merge_params) . ' ' . $merge_command->error_message);
            die $self->error_message;
        }

        $self->_merged_bed_file_path($temp_file);
    }

    return $self->_merged_bed_file_path;
}

sub _resolve_param_value_from_text_by_name_or_id {
    my $class = shift;
    my $param_arg = shift;

    #First try default behaviour of looking up by name or id
    my @results = Genome::Command::Base->_resolve_param_value_from_text_by_name_or_id($class, $param_arg);

    #If that didn't work, and the argument is a filename, see if we have a feature list matching the provided file.
    if(!@results and -f $param_arg) {
        my $md5 = Genome::Sys->md5sum($param_arg);
        @results = Genome::FeatureList->get(file_content_hash => $md5);

        @results = grep( !Genome::Sys->diff_file_vs_file($param_arg, $_->file_path), @results);
    }

    return @results;
}

1;
