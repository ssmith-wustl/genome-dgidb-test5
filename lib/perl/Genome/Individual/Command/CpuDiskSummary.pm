package Genome::Individual::Command::CpuDiskSummary;

use strict;
use warnings;

use Genome;

class Genome::Individual::Command::CpuDiskSummary {
    is => 'Command::V2',
    has => [
        patients    => { is => 'Genome::Individual', 
                        shell_args_position => 1,
                        require_user_verify => 0, 
                        is_input => 1,
                        is_many => 1,
                        doc => 'patients on which to report', 
                    },
        output_file => { is => 'FilePath',
                        is_optional => 1,
                        default_value => '-',
                        doc => 'write to this file instead of STDOUT',
                    },
        format      => { is => 'Text',
                        valid_values => ['table','raw'],
                        default_value => 'table',
                        doc => 'set to raw for a raw dump of the data'
                    },
        builds      => {
                        is => 'Genome::Model::Build',
                        is_optional => 1,
                        is_many => 1,
                        require_user_verify => 0,
                        doc => 'limit report to these somatic builds'
                    }
    ],
    doc => 'summarize resources used for a particular patient'
};

sub sub_command_sort_position { 2 }

sub execute {
    my $self = shift;

    my @patients = $self->patients;
    my @patient_ids = map { $_->id } @patients; 
    
    my @samples = Genome::Sample->get(source_id => \@patient_ids);
    my @patient_and_sample_ids = (@patient_ids, map { $_->id } @samples);

    my @somatic_models = Genome::Model::SomaticVariation->get(subject_id => \@patient_and_sample_ids );
    my @somatic_builds = Genome::Model::Build->get(model_id => [ map { $_->id } @somatic_models ]);

    my @force_build_ids;
    if (my @builds = $self->builds) {
        @force_build_ids = map { $_->id } @builds;
    }

    my @row_names = (
        'Individual',
        'Tumor Gbases', 
        'Normal Gbases',
        'Tumor RefAlign (GB)', 
        'Normal RefAlign (GB)',
        'Tumor RefAlign (slot*hr)', 
        'Normal RefAlign (slot*hr)',
        'Somatic (GB)', 
        'Somatic (slot*hr)',
        '---',
    );
    my %expected_row_names;
    @expected_row_names{@row_names} = @row_names;
   
    my @columns; 
    for my $patient (sort { $a->common_name cmp $b->common_name } @patients) {
        my %f;
        push @columns, \%f;

        $f{"Individual"} = $patient->common_name;

        my @somatic_models = Genome::Model->get(
            type_name => ['somatic','somatic variation'],           # old/new
            subject_id => [$patient->id, map { $_->id } $patient->samples],     # old/new
        );

        unless (@somatic_models) {
            $self->error_message("no somatic models for " . $patient->__display_name__ . "\n");
            next;
        }

        my @somatic_builds;
        for my $model (reverse @somatic_models) {
            my @builds = $model->builds(
                (@force_build_ids ? (id => \@force_build_ids) : ()) # (status => 'Succeeded')) 
            );

            push @somatic_builds, @builds;
        }

        unless (@somatic_builds) {
            $self->error_message("no builds on somatic models for patient " . $patient->__display_name__);
            next;
        }

        my %seen_builds;
        my %seen_dirs;
        for my $somatic_build (@somatic_builds) {
            
            $self->status_message(
                "patient " . $patient->__display_name__ . ' using build ' . $somatic_build->__display_name__ . "\n"
            );

            my $somatic_alloc1 = $somatic_build->disk_allocation;

            $f{"somatic_build"} .= $somatic_build->__display_name__;
            $f{"Somatic (slot*hr)"} += (eval { $somatic_build->cpu_slot_hours } || 0);
            $f{"Somatic (GB)"} += $somatic_alloc1->kilobytes_requested / (1024**2);

            my $tumor_model = $somatic_build->model->tumor_model;
            my $normal_model = $somatic_build->model->normal_model;
           
            my @tumor_builds = $tumor_model->builds;
            my @normal_builds = $normal_model->builds;

            # T
            
            for my $tumor_build (@tumor_builds) {
                next if $seen_builds{$tumor_build->id};
                $seen_builds{$tumor_build->id} = $tumor_build;

                my $tumor_bam_dir;
                my $gb_regular = 0;
                if ($tumor_build) {
                    $f{tumor_build} .= $tumor_build->__display_name__;
                    $f{"Tumor RefAlign (slot*hr)"} += (eval { $tumor_build->cpu_slot_hours("event_type not like" => '%align-reads%') } || 0);
                    my $tumor_alloc1 = $tumor_build->disk_allocation;
                    $gb_regular = ($tumor_alloc1->kilobytes_requested / (1024**2));
                    $f{"Tumor RefAlign GB regular"} += $gb_regular; 
                    $tumor_bam_dir = $tumor_build->accumulated_alignments_directory;

                    my $tumor_bam_size;
                    my $dir = $tumor_bam_dir;
                    while (-l $dir) {
                        $dir = readlink($dir);
                    }
                    $dir =~ s|^.*build_merged_alignments|build_merged_alignments|;
                    if ($seen_dirs{$dir}) {
                        $tumor_bam_size = 0;
                        warn "skipping dir $dir\n";
                    }
                    else {
                        $seen_dirs{$dir} = 1;
                        my $tumor_alloc = Genome::Disk::Allocation->get(allocation_path => $dir);
                        $tumor_bam_size = ($tumor_alloc ? ($tumor_alloc->kilobytes_requested / (1024**2)) : 0); 
                        $f{"Tumor RefAlign GB bam"} += $tumor_bam_size; 
                    }
                    $f{"Tumor RefAlign (GB)"} += ($gb_regular + $tumor_bam_size);
                }
                
                #$tumor_metric  = $tumor_build->metric(name => 'instrument_data_total kb');
                $f{"Tumor Gbases"} ||= eval { $tumor_build->metric(name => 'instrument data total kb')->value/1_000_000 };
            }

            # N
            
            for my $normal_build (@normal_builds) {
                next if $seen_builds{$normal_build->id};
                $seen_builds{$normal_build->id} = $normal_build;

                my $normal_bam_dir;
                my $gb_regular = 0;
                if ($normal_build) {
                    $f{normal_build} .= " " . $normal_build->__display_name__;
                    $f{"Normal RefAlign (slot*hr)"} += (eval { $normal_build->cpu_slot_hours("event_type not like" => '%align-reads%') } || 0);
                    my $normal_alloc1 = $normal_build->disk_allocation;
                    if ($normal_alloc1) {
                        $gb_regular = ($normal_alloc1->kilobytes_requested / (1024**2));
                        $f{"Normal RefAlign GB regular"} += $gb_regular; 
                    }
                    else {
                        warn "no allocation for build " . $normal_build->__display_name__;
                    }

                    $normal_bam_dir = $normal_build->accumulated_alignments_directory;
                    my $normal_bam_size = 0;
                    if ($normal_bam_dir) {
                        my $dir = $normal_bam_dir;
                        while (-l $dir) {
                            $dir = readlink($dir);
                        }
                        $dir =~ s|^.*build_merged_alignments|build_merged_alignments|;
                        if ($seen_dirs{$dir}) {
                            $normal_bam_size = 0;
                            #warn "skipping dir $dir\n";
                        }
                        else {
                            $seen_dirs{$dir} = 1;
                            #warn "not skipping $dir, seen " . join(",",keys %seen_dirs);
                            my $normal_alloc = Genome::Disk::Allocation->get(allocation_path => $dir);
                            $normal_bam_size = ($normal_alloc ? ($normal_alloc->kilobytes_requested / (1024**2)) : 0); 
                            $f{"Normal RefAlign GB bam"} += $normal_bam_size; 
                        }
                    }
                    $f{"Normal RefAlign (GB)"} += ($gb_regular + $normal_bam_size);
                }
                
                #$normal_metric  = $normal_build->metric(name => 'instrument_data_total kb');
                $f{"Normal Gbases"} ||= eval { $normal_build->metric(name => 'instrument data total kb')->value/1_000_000 };
            }

            # OTHER

            my $max_length = 0;
            for (values %f) {
                my $length = length($_);
                $max_length = $length if $max_length < $length;
            }
            $f{max_length} = $max_length;

            # non-essential columns may be added as well
            for my $key (keys %f) {
                unless ($expected_row_names{$key}) {
                    $expected_row_names{$key} = 1;
                    push @row_names, $key;
                }
            }
        }
    }

    my $outfh = Genome::Sys->open_file_for_writing($self->output_file);
    if ($self->format eq 'table') {
        no warnings;
        my $max_row_name_length = 0;
        for (@row_names) {
            my $length = length($_);
            $max_row_name_length = $length if $max_row_name_length < $length;
        }

        for my $row_name (@row_names) {
            #my $value = ' ' x ($max_row_name_length - length($row_name)) . $row_name;

            $outfh->print($row_name,"\t");

            for my $col (@columns) {
                my $value = $col->{$row_name};
                #$value = ' ' x ($col->{max_length} - length($value)) . $value;
                $outfh->print($value);
            }
            continue {
                $outfh->print("\t");
            }
            $outfh->print("\n");
        }
    }
    elsif($self->format eq 'raw') {
        $outfh->print(Data::Dumper::Dumper(\@columns));
    }
    else {
        die "unknown output format " . $self->format . "???";
    }

    return 1;
}

1;

