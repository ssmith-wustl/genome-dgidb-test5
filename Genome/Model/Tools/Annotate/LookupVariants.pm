
# review jlolofie
# 1. last matching line should be the new min everytime (for each chromosome file)
# 2. this should be benchmarked against another intersect tool to figure out which is faster-
#    depends on the density of the data

package Genome::Model::Tools::Annotate::LookupVariants;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use IO::File;

class Genome::Model::Tools::Annotate::LookupVariants {
    is  => 'Genome::Model::Tools::Annotate',
    has => [
        variant_file => {
            type     => 'Text',
            is_input => 1,
            doc      =>
                "File of variants. TSV (sorted by chromosome,start): chromosome_name start stop reference variant",
        },
        output_file => {
            type      => 'Text',
            is_input  => 1,
            is_output => 1,
            default   => "STDOUT",
            doc       => "default is STDOUT",
        },
    ],
    has_optional => [
        _output_filehandle => {
            type      => 'SCALAR',
        },
        _last_data_line_number => {
            type      => 'SCALAR',
            doc => 'The number of lines in the input',
        },
        filter_out_submitters => {
            type     => 'Text',
            is_input => 1,
            doc      =>
                'Comma separated (no spaces allowed) list of submitters to IGNORE from dbsnp',
        },
        dbSNP_path => {
            type     => 'Text',
            default  => '/gscmnt/sata835/info/medseq/imported_variations/dbSNP/130/',
            doc      => "path to dbSNP files broken into chromosome",
        },
        report_mode => {
            type     => 'Text',
            is_input => 1,
            default  => 'novel-only',
            doc      =>
                'novel-only (DEFAULT VALUE) prints lines from variant_file that are not found in dbSNP
                    known-only prints lines from variant file that are found in dbSNP',
        },
        index_fixed_width => {
            type     => 'Int',
            default  => 10,
            doc      => "look, dont change this, ok?"
        },
        group_by_position => {
            type     => 'Boolean',
            default  => 0,
            doc      => "only matters if report_mode is known-only"
        },
        print_dbsnp_lines => {
            type     => 'Boolean',
            default  => 0,
            doc      => 'print matching dbSNP line isntead of input',
        },
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
    ],
};


sub help_synopsis { 
    return <<EOS
gmt annotate lookup-variants --variant-file snvs.csv --output-file novel_variants.csv
EOS
}

sub help_detail {
    return <<EOS
By default, takes in a file of variants and filters out variants that are already known to exist.
EOS
}

sub execute { 

    my ($self) = @_;

    if (($self->skip_if_output_present)&&(-s $self->output_file)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    my $variant_file = $self->variant_file;
    open(my $in, $variant_file) || die "cant open $variant_file";

    my $fh = $self->get_output_fh() || die 'no output filehandle';
    $self->_output_filehandle($fh);

    while (my $line = <$in>) {

        if ($self->filter_out_submitters) {
            $self->print_input_lines_with_filters($line);
        } else {
            if ($self->print_dbsnp_lines) {
                $self->print_db_snp_lines_without_filters($line);
            } else {
                $self->print_input_lines_without_filters($line);
            }
        }
    }

    close($in);
    $fh->close;

    return 1;
}

sub print_input_lines_with_filters {

    my ($self, $line) = @_;

    my $fh = $self->_output_filehandle() || die 'no output_filehandle';
    my $report_mode = $self->report_mode();
    my @matches = $self->find_all_matches($line);

    @matches = map { $self->filter_by_submitters($_) } @matches;
    @matches = map { $self->filter_by_type($_) } @matches; 

    if (($report_mode eq 'known-only')&&(@matches)) {
        $fh->print($line);
    } elsif (($report_mode eq 'novel-only')&& (scalar @matches == 0)) {
        $fh->print($line);
    }
}

sub print_input_lines_without_filters {

    my ($self, $line) = @_;

    my $fh = $self->_output_filehandle() || die 'no output_filehandle';
    my $pos = $self->find_a_matching_pos($line);
    my $report_mode = $self->report_mode();

    if ($report_mode eq 'novel-only' && !defined($pos)) {
        $fh->print($line);
    }
    
    if ($report_mode eq 'known-only' && defined($pos)) {
        $fh->print($line);
    }
}

sub get_output_fh {
    my $self = shift;

    my $output_file = $self->output_file();
    die 'no output_file!' if !$output_file;

    if ($output_file eq 'STDOUT') {
        return 'STDOUT';
    }

    my $fh = IO::File->new(">" . $output_file);
    return $fh;
}

sub print_db_snp_lines_without_filters {
    my ($self, $line) = @_;

    my $fh = $self->_output_filehandle() || die 'no output_filehandle';
    my $report_mode = $self->report_mode();
    my @matches = $self->find_all_matches($line);

    if ( $report_mode eq 'novel-only' && !@matches ) {
        $fh->print($line);
    }

    my $group_by_position = $self->group_by_position();
    if ( $report_mode eq 'known-only' ) {

        if ($group_by_position) {
            # novel-only is automatically group by position, yeah?
            @matches= $self->group_variants_by_position(\@matches);            
        }

        $fh->print($_) for @matches;
    }

    return 1;
}

sub filter_by_submitters {
    
    my ($self, $line) = @_;

    my ( $ds_id, $ds_allele, $ds_type, $ds_chr, $ds_start, $ds_stop,
        $ds_submitter )
        = split( /\t/, $line );

    my $submitters_str = $self->filter_out_submitters();
    return $line if !$submitters_str;

    my @filter_submitters = split(/,/,$submitters_str);
    if (grep /^$ds_submitter$/, @filter_submitters) {
        return;
    }

    return $line;
}

sub filter_by_type {

    my ($self, $line) = @_;

    my ( $ds_id, $ds_allele, $ds_type, $ds_chr, $ds_start, $ds_stop,
        $ds_submitter )
        = split( /\t/, $line );

    if ($ds_type eq 'SNP'
        && $ds_start == $ds_stop) {
        return $line;
    }

    return;
}

sub find_all_matches {

    my ($self, $line) = @_;
    my @matches;

    my $pos = $self->find_a_matching_pos($line);
    if (defined ($pos)) {
        my ($chr, $start, $stop) = split(/\t/,$line);
        @matches = $self->find_matches_around($chr, $pos);
    }

    return @matches;
}

sub find_matches_around {

    my ($self, $chr, $pos) = @_;
    my $variant = {};
    my (@forward, @backward);

    if ($chr =~ /^(MT|NT)/) {
        return;
    }

    my ($fh, $index) = $self->get_fh_for_chr($chr);

    my ( $ds_id, $ds_allele, $ds_type, $ds_chr, $ds_start, $ds_stop, $ds_submitter );
    my $cur = $pos;
    my $line = $self->get_line($fh, $index, $cur);
    ( $ds_id, $ds_allele, $ds_type, $ds_chr, $ds_start, $ds_stop, $ds_submitter )
        = split( /\t/, $line );
    my $start = $ds_start;

    push @forward, $line;
   
    # go forward 
    while ($cur == $pos || $start == $ds_start) {
        $cur++;
        last if ($cur > $self->_last_data_line_number);
        
        $line = $self->get_line($fh, $index, $cur);
        last if !$line;

        ( $ds_id, $ds_allele, $ds_type, $ds_chr, $ds_start, $ds_stop, $ds_submitter )
            = split( /\t/, $line );

        if ($start == $ds_start) {
            push @forward, $line;
        }
    }

    # go backwards
    $cur = $pos; 
    while ($cur == $pos || $start == $ds_start) {
        $cur--;
        last if ($cur < 0);

        $line = $self->get_line($fh, $index, $cur);
        last if !$line;

        ( $ds_id, $ds_allele, $ds_type, $ds_chr, $ds_start, $ds_stop, $ds_submitter )
            = split( /\t/, $line );

        if ($start == $ds_start) {
            push @backward, $line;
        }
    } 

    return (reverse @backward, @forward);
}

sub find_a_matching_pos {

    my ($self, $line) = @_;

    my ($chr, $start, $stop) = split(/\t/,$line);

    if ($chr =~ /^(MT|NT)/) {
        return;
    }

    my ($fh, $index) = $self->get_fh_for_chr($chr);
    my $match_count = 0;
    my $size = <$index>; chomp($size);
    my $min = 0;
    my $max = $size - 1;
    $self->_last_data_line_number($max);

    while($min <= $max) {

        my $cur += $min + int(($max - $min) / 2);

        my $line = $self->get_line($fh, $index, $cur);

        my ( $ds_id, $ds_allele, $ds_type, $ds_chr, $ds_start, $ds_stop, $ds_submitter )
            = split( /\t/, $line );

        if ($start > $ds_start) {
            $min = $cur + 1;
        } elsif ($start < $ds_start) { 
            $max = $cur - 1;
        } else {
            return $cur;
        }
    }

    return;
}

sub get_line {

    my ($self, $fh, $index, $line_number) = @_;
    my $fixed_width = $self->index_fixed_width();

    # add fixed width to account for index header
    my $index_pos = $line_number * $fixed_width + $fixed_width;
    seek($index, $index_pos, 0);
    my $pos = <$index>; chomp($pos);
   
    seek($fh, $pos, 0);
    my $line = <$fh>;
    return $line; 
}

sub get_fh_for_chr {

    my ($self, $chr) = @_;

    my $dbSNP_path = $self->dbSNP_path();
    my ($fh, $index);
    my $f = $self->{'filehandles'};
    my $i = $self->{'index_filehandles'};

    if (!$f->{$chr}) {
        my $dbSNP_filename = join('',  'variations_', $chr, '.csv');
        my $dbSNP_pathname = join('/',$dbSNP_path,$dbSNP_filename); 
        die "cant open dbSNP_pathname = $dbSNP_pathname" if ! -e $dbSNP_pathname ;

        my $index_filename = join('',  'variations_', $chr, '.csv.index');
        my $index_pathname = join('/',$dbSNP_path,$index_filename); 
        die "cant open index_pathname = $index_pathname" if ! -e $index_pathname ;

        open($fh, $dbSNP_pathname);
        $f->{$chr} = $fh;

        open($index, $index_pathname);
        $i->{$chr} = $index;
    } else {
        $fh = $f->{$chr};
        seek($fh, 0, 0);

        $index = $i->{$chr};
        seek($index, 0, 0);
    }

    die "no filehandle for $chr" if !$fh || !$index;

    return ($fh, $index);
}

sub group_variants_by_position {

    my ($self, $v) = @_;
    my %lines_without_submitter;
    my %variant_groups;
    my @variants;

    for my $v (@$v) {

        my ( $ds_id, $ds_allele, $ds_type, $ds_chr, $ds_start, $ds_stop, $ds_submitter )
            = split( /\t/, $v );
        my $line_without_submitter = join("\t", ( $ds_id, $ds_allele, $ds_type, $ds_chr, $ds_start, $ds_stop ));
        $lines_without_submitter{$ds_start} = $line_without_submitter;
        push @{$variant_groups{$ds_start}}, $ds_submitter;
    }
  
    for my $ds_start (keys %variant_groups) {
        my $submitter_str = join(',', @{$variant_groups{$ds_start}});
        my $new_line = join("\t", $lines_without_submitter{$ds_start}, $submitter_str);
        $new_line .= "\n";
        push @variants, $new_line;
    } 

    return @variants;
}


1;






=pod

=head1 Name

Genome::Model::Tools::Annotate::LookupVariations

=head1 Synopsis

By default, takes in a file of variants and filters out variants that are already known to exist.

=head1 Usage

    $ gmt annotate lookup-variants --variant-file snvs.csv --output-file novel_variants.csv
 
=cut


