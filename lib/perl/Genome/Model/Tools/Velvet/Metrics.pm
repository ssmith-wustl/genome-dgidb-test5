package Genome::Model::Tools::Velvet::Metrics;

use strict;
use warnings;

use Genome;

use AMOS::AmosLib;

class Genome::Model::Tools::Velvet::Metrics {
    is => 'Genome::Model::Tools::Velvet::Base',
    has => [
	    first_tier => {
            type => 'Integer',
            is_optional => 1,
            doc => "first tier value",
        },
        second_tier => {
            type => 'Integer',
            is_optional => 1,
            doc => "second tier value",
        },
        assembly_directory => {
            type => 'Text',
            is_optional => 1,
            doc => "path to assembly",
        },
        major_contig_length => {
            type => 'Integer',
            is_optional => 1,
            default_value => 500,
            doc => "Major contig length cutoff",
        },
        output_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'Stats output file',
        },
    ],
};

sub help_brief {
    return 'Produce metrics for velvet assemblies'
}

sub __errors__ {
    my $self = shift;

    my @errors = $self->SUPER::__errors__(@_);
    return @errors if @errors;

    if ( $self->assembly_directory ) {
        if ( not -d $self->assembly_directory ) {
            push @errors, UR::Object::Tag->create(
                type => 'invalid',
                properties => [qw/ assembly_directory /],
                desc => 'The assembly_directory is not a directory!',
            );
            return @errors;
        }
        if ( not defined $self->output_file ) {
            my $create_edit_dir = $self->create_edit_dir;
            return if not $create_edit_dir;
            $self->output_file( $self->stats_file );
        }
    }
    elsif ( not $self->output_file ) { 
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ output_file /],
            desc => 'No output file given and no assembly_directory given to determine the output file!',
        );
    }

    my $reads_file = $self->input_collated_fastq_file;
    if ( not -s $reads_file ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ assembly_directory /],
            desc => 'No input reads file found in assembly_directory:'.$self->assembly_directory,
        );
    }

    return @errors;
}

sub execute {
    my $self = shift;
    $self->status_message('Velvet metrics...');

    # input files
    my $resolve_post_assembly_files = $self->_validate_or_create_post_assembly_files;
    return if not $resolve_post_assembly_files;
    my $contigs_bases_file = $self->resolve_contigs_bases_file;

    # tier values
    my ($t1, $t2);
    if ($self->first_tier and $self->second_tier) {
        $t1 = $self->first_tier;
        $t2 = $self->second_tier;
    }
    else {
        my $est_genome_size = -s $contigs_bases_file;
        $t1 = int ($est_genome_size * 0.2);
        $t2 = int ($est_genome_size * 0.2);
    }
    $self->status_message('Tier one: 1 to '.$t1);
    $self->status_message('Tier two: '.$t1.' to '.($t1 + $t2));

    # metrics
    my $metrics = Genome::Model::Tools::Sx::Metrics::Assembly->create(
        major_contig_threshold => $self->major_contig_length,
        tier_one => $t1,
        tier_two => $t2,
    );

    # add contigs
    $self->status_message('Add contigs bases file: '.$contigs_bases_file);
    my $add_contigs_ok = $metrics->add_contigs_file_with_contents($contigs_bases_file.':type=fasta');
    return if not $add_contigs_ok;

    # reads
    my $reads_file = $self->input_collated_fastq_file;
    $self->status_message('Add reads file: '.$reads_file);
    my $add_reads = $metrics->add_reads_file_with_q20($reads_file);
    return if not $add_reads;

    # reads placed
    $self->status_message('Add reads placed: '.$self->resolve_reads_placed_file);
    my $add_reads_placed = $self->_add_reads_placed_to_metrics($metrics);
    return if not $add_reads_placed;

    # reads placed
    $self->status_message('Add read depths: '.$self->resolve_afg_file);
    my $add_read_depth = $self->_add_read_depth_to_metrics($metrics);
    return if not $add_read_depth;
    
    # transform metrics
    my $text = $metrics->transform_xml_to('txt');
    if ( not $text ) {
        $self->error_message('Failed to transform metrics to text!');
        return;
    }

    # write file
    my $output_file = $self->output_file;
    unlink $output_file if -e $output_file;
    $self->status_message('Write output file: '.$output_file);
    my $fh = eval{ Genome::Sys->open_file_for_writing($output_file); };
    if ( not $fh ) {
        $self->error_message('Failed to open metrics output file!');
        return;
    }
    $fh->print($text);
    $fh->close;

    $self->status_message('Velvet metrics...DONE');
    return 1;
}

sub _validate_or_create_post_assembly_files {
    my $self = shift;

    # afg
    my $afg_file = $self->resolve_afg_file;
    if ( not -s $afg_file ) {
        $self->error_message('No velvet afg file in assembly directory: '.$self->assembly_directory);
        return;
    }

    # contigs files
    my $contigs_bases = $self->resolve_contigs_bases_file;
    unless ( -s $contigs_bases ) {
        my $tool = Genome::Model::Tools::Velvet::CreateContigsFiles->create(
            assembly_directory => $self->assembly_directory,
            min_contig_length => 1,
        );
        unless( $tool->execute ) {
            $self->error_message("Failed to create contigs bases/quals files for stats");
            return;
        }
    }

    # gap file
    my $gap_sizes_file = $self->resolve_gap_sizes_file;
    unless ( -e $gap_sizes_file ) {
        my $tool = Genome::Model::Tools::Velvet::CreateGapFile->create(
            assembly_directory => $self->assembly_directory,
        );
        unless( $tool->execute ) {
            $self->error_message("Failed to create gap.txt file for stats");
            return;
        }
    }

    #reads files
    my $reads_info_file = $self->resolve_read_info_file;
    my $reads_placed_file = $self->resolve_reads_placed_file;
    unless ( -s $reads_info_file and -s $reads_placed_file ) {
        my $tool = Genome::Model::Tools::Velvet::CreateReadsFiles->create(
            assembly_directory => $self->assembly_directory,
        );
        unless( $tool->execute ) {
            $self->error_message("Failed to create readinfo and reads.placed files for stats");
            return;
        }
    }

    return 1;
}

sub _add_reads_placed_to_metrics {
    my ($self, $metrics) = @_;

    my $fh = eval{ Genome::Sys->open_file_for_reading($self->resolve_reads_placed_file); };
    return if not $fh;

    my %uniq_reads;
    my $reads_placed_in_scaffolds = 0;
    while ( my $line = $fh->getline ) {
        $reads_placed_in_scaffolds++;
        my ($read_name) = $line =~ /^\*\s+(\S+)\s+/;
        $read_name =~ s/\-\d+$//;
        $uniq_reads{$read_name}++;
    }
    $fh->close;

    $metrics->set_metric('reads_placed', $reads_placed_in_scaffolds);

    my $reads_placed_unique = keys %uniq_reads;
    $metrics->set_metric('reads_placed_unique', $reads_placed_unique);
    $metrics->set_metric('reads_placed_duplicate', ($reads_placed_in_scaffolds - $reads_placed_unique));

    my $reads_count = $metrics->get_metric('reads_count');
    my $reads_unplaced = $reads_count - $reads_placed_unique;
    $metrics->set_metric('reads_unplaced', $reads_unplaced);

    return 1;
}

sub _add_read_depth_to_metrics { #for velvet assemblies
    my ($self, $metrics) = @_;

    my $afg_fh = eval{ Genome::Sys->open_file_for_reading($self->resolve_afg_file); };
    return if not $afg_fh;

    my ($one_x_cov, $two_x_cov, $three_x_cov, $four_x_cov, $five_x_cov, $uncovered_pos, $total_consensus_pos) = (qw/ 0 0 0 0 0 0 0 /);

    while (my $record = getRecord($afg_fh)) {
        my ($rec, $fields, $recs) = parseRecord($record);
        if ($rec eq 'CTG') {  #contig
            my $seq = $fields->{seq}; #fasta
            $seq =~ s/\n//g; #contig seq is written in multiple lines
            my $contig_length = length $seq;
            my @consensus_positions;
            for my $r (0..$#$recs) { #reads
                my ($srec, $sfields, $srecs) = parseRecord($recs->[$r]);

                #sfields
                #'src' => '19534',  #read id number
                #'clr' => '0,90',   #read start, stop 0,90 = uncomp 90,0 = comp
                #'off' => '75'      #read off set .. contig start position

                my ($left_pos, $right_pos) = split(',', $sfields->{clr});
                #disregard complementation .. set lower values as left_pos and higher value as right pos
                ($left_pos, $right_pos) = $left_pos < $right_pos ? ($left_pos, $right_pos) : ($right_pos, $left_pos);
                #left pos has to be incremented by one since it started at zero
                $left_pos += 1;
                #account for read off set
                $left_pos += $sfields->{off};
                $right_pos += $sfields->{off};
                #limit left and right position to within the boundary of the contig
                $left_pos = 1 if $left_pos < 1;  #read overhangs to left
                $right_pos = $contig_length if $right_pos > $contig_length; #to right

                for ($left_pos .. $right_pos) {
                    $consensus_positions[$_]++;
                }
            }
            $total_consensus_pos += $#consensus_positions;
            shift @consensus_positions; #remove [0] position 
            #
            if (scalar @consensus_positions < $contig_length) {
                $self->warning_message ("Covered consensus bases does not equal contig length\n\t".
                    "got ".scalar (@consensus_positions)." covered bases but contig length is $contig_length\n");
                $uncovered_pos += ( $contig_length - scalar @consensus_positions );
                $total_consensus_pos += ( $contig_length - scalar @consensus_positions );
            }
            foreach (@consensus_positions) {
                if ( not defined $_ ) { #not covered consensus .. probably an error in velvet afg file
                    $uncovered_pos++;
                    next;
                }
                $five_x_cov++  and next if $_ >= 5;
                $four_x_cov++  and next if $_ == 4;
                $three_x_cov++ and next if $_ == 3;
                $two_x_cov++   and next if $_ == 2;
                $one_x_cov++   if $_ == 1;
            }
        }
    }
    $afg_fh->close;

    $metrics->set_metric('coverage_5x', $five_x_cov);
    $metrics->set_metric('coverage_4x', $four_x_cov  + $five_x_cov);
    $metrics->set_metric('coverage_3x', $three_x_cov + $five_x_cov + $four_x_cov);
    $metrics->set_metric('coverage_2x', $two_x_cov + $five_x_cov + $four_x_cov + $three_x_cov);
    $metrics->set_metric('coverage_1x', $one_x_cov + $five_x_cov + $four_x_cov + $three_x_cov + $two_x_cov);
    $metrics->set_metric('coverage_0x', $uncovered_pos) if $uncovered_pos > 0;  # this is possible somehow

    return 1;
}

1;

