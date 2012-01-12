package Genome::Model::Tools::Newbler::Metrics;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Newbler::Metrics {
    is => 'Genome::Model::Tools::Newbler',
    has => [
        assembly_directory => {
            is => 'Text',
            doc => 'Path to soap assembly',
        },
    ],
    has_optional => [
        first_tier => {
            is => 'Number',
            doc => 'First tier value',
        },
        second_tier => {
            is => 'Number',
            doc => 'Second tier value',
        },
        major_contig_length => {
            is => 'Number',
            default_value => 500,
            doc => 'Cutoff value for major contig length',
        },
        output_file => {
            is => 'Text',
            doc => 'Stats output file',
        },
        _metrics => { is_transient => 1, },
    ],
};

sub help_brief {
    return 'Produce metrics for newbler assemblies'
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
            my $create_dir = $self->create_consed_edit_dir;
            return if not $create_dir;
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

    my @reads_files = grep { -s } $self->input_fastq_files;
    if ( not @reads_files ) {
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ assembly_directory /],
            desc => 'No input reads files found in assembly_directory: '.$self->assembly_directory,
        );
    }

    return @errors;
}

sub execute {
    my $self = shift;
    $self->status_message('Newbler metrics...');

    # input files
    #my $resolve_post_assembly_files = $self->_validate_or_create_post_assembly_files;
    #return if not $resolve_post_assembly_files;
    my $contigs_bases_file = $self->contigs_bases_file;

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
    $self->_metrics($metrics);

    # add contigs
    $self->status_message('Add contigs bases file: '.$contigs_bases_file);
    my $add_contigs_ok = $metrics->add_contigs_file_with_contents($contigs_bases_file.':type=fasta');
    return if not $add_contigs_ok;

    # reads
    for my $reads_file ( $self->input_fastq_files ) {
        $self->status_message('Add reads file: '.$reads_file);
        my $add_reads = $metrics->add_reads_file_with_q20($reads_file);
        return if not $add_reads;
    }

    # reads assembled (placed)
    $self->status_message('Add reads assembled: '.$self->newb_metrics_file);
    my $add_reads_assembled = $self->_add_reads_assembled_to_metrics($metrics);
    return if not $add_reads_assembled;

    # reads assembled
    $self->status_message('Add read depths: '.$self->read_info_file);
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

sub _add_reads_assembled_to_metrics {
    my ($self, $metrics) = @_;

    unless( -s $self->newb_metrics_file ) {
        $self->error_message( "Failed to find newbler read stats file: ".$self->newb_metrics_file );
        return;
    }

    my $reads_assembled;
    my $fh = eval{ Genome::Sys->open_file_for_reading( $self->newb_metrics_file ); };
    if ( not $fh ) {
        $self->error_message('Failed to open newbler metrics file: '.$self->newb_metrics_file);
        return;
    }
    while ( my $line = $fh->getline ) {
        if ( $line =~ /\s+numberAssembled\s+\=\s+(\d+)/ ) {
            $reads_assembled = $1;
            last;
        }
    }
    $fh->close;

    if ( not $reads_assembled ) {
        $self->error_message("Failed to get assembled reads from metrics file. Expected a line like this: 'numberAssembled = 3200' in file but did't find one" );
        return;
    }

    $metrics->set_metric('reads_assembled', $reads_assembled);

    return 1;
}

sub _add_read_depth_to_metrics {
    my ($self, $metrics) = @_;

    my %coverage;

    my $total_covered_pos = 0;
    my $five_x_cov = 0;
    my $four_x_cov = 0;
    my $three_x_cov = 0;
    my $two_x_cov = 0;
    my $one_x_cov = 0;

    my $fh = Genome::Sys->open_file_for_reading( $self->read_info_file );
    while ( my $line = $fh->getline ) {
        my @tmp = split( /\s+/, $line );
        #$tmp[0] = read name
        #$tmp[1] = contig name
        #$tmp[3] = read start position
        #$tmp[4] = read length
        my $from = $tmp[3];               #coverage start
        my $to = $tmp[3] + $tmp[4] - 1;   #coverage end
        for my $pos ( $from .. $to ) {
            $pos -= 1;
            @{ $coverage{$tmp[1]} }[$pos]++;
        }
    }
    $fh->close;
    
    for my $contig ( keys %coverage ) {
        $total_covered_pos += scalar @{$coverage{$contig}};
        for my $pos ( @{$coverage{$contig}} ) {
            $one_x_cov++ if $pos > 0;
            $two_x_cov++ if $pos > 1;
            $three_x_cov++ if $pos > 2;
            $four_x_cov++ if $pos > 3;
            $five_x_cov++ if $pos > 4;
        }
    }

    $metrics->set_metric('coverage_5x', $five_x_cov);
    $metrics->set_metric('coverage_4x', $four_x_cov);
    $metrics->set_metric('coverage_3x', $three_x_cov);
    $metrics->set_metric('coverage_2x', $two_x_cov);
    $metrics->set_metric('coverage_1x', $one_x_cov);
    $metrics->set_metric('coverage_0x', 0);

    return 1;
}

1;

