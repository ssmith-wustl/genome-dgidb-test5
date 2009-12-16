
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

#            default  => '/gscmnt/sata835/info/medseq/imported_variations/dbSNP/130/',

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
            default  => '/gsc/var/lib/import/dbsnp/130/tmp/',
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
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
        append_rs_id => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'append rs_id from dbSNP at end of each matching row'
        }
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

$DB::single = 1;

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
        $self->print_matches($line);
    }

    close($in);
    $fh->close;

    return 1;
}

sub print_matches {

    my ($self, $line) = @_;

    my @matches;

    if ($self->filter_out_submitters()) {
        @matches = $self->find_all_matches($line);
        @matches = map { $self->filter_by_submitters($_) } @matches;
        @matches = map { $self->filter_by_type($_) } @matches; 
    } else {
        @matches = $self->find_a_matching_pos($line);
    }

    my $fh = $self->_output_filehandle() || die 'no output_filehandle';
    my $report_mode = $self->report_mode();
    if (($report_mode eq 'known-only')&&(@matches)) {

        if ($self->append_rs_id()) {

            my ($chr, $start, $stop) = split(/\t/,$line);
            my ($dbsnp_fh, $index) = $self->get_fh_for_chr($chr);
            my $snp_line = $self->get_line($dbsnp_fh, $index, $matches[0]);
            my $snp = parse_dbsnp_line($snp_line);
            my $rs_id = $snp->{'rs_id'};
            chomp($line);
            $line = sprintf("%s\t%s\n",$line,$rs_id); 
        }

        $fh->print($line);
    } elsif (($report_mode eq 'novel-only')&& (scalar @matches == 0)) {
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

sub filter_by_submitters {

    my ($self, $line) = @_;

    # NOTE: submitters are 1 per line in dbsnp data source files,
    # but are comma separated list on command line

    my $snp = parse_dbsnp_line($line);    
    my $ds_submitter = $snp->{'ds_submitter'};

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
    # returns $line if its a SNP

    my $snp = parse_dbsnp_line($line);

    if ($snp->{'ds_type'} eq 'SNP'
        && $snp->{'ds_start'} == $snp->{'ds_stop'}) {
        return $line;
    }

    return;
}

sub find_all_matches {

    # TODO: the problem is we only return position, not chromosome, etc

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

    my $cur = $pos;
    my $original_line = $self->get_line($fh, $index, $cur);

    my $snp = parse_dbsnp_line($original_line);
    my $ds_start = $snp->{'ds_start'};
    my $start = $ds_start;

    push @forward, $original_line;
   
    # go forward 
    while ($cur == $pos || $start == $ds_start) {
        $cur++;
        last if ($cur > $self->_last_data_line_number);
        
        my $forward_line = $self->get_line($fh, $index, $cur);
        last if !$forward_line;

        my $forward_snp = parse_dbsnp_line($forward_line);
        $ds_start = $forward_snp->{'ds_start'};
        if ($start == $ds_start) {
            push @forward, $forward_line;
        }
    }

    # reset and go backwards
    $ds_start = $start;
    $cur = $pos; 
    while ($cur == $pos || $start == $ds_start) {
        $cur--;
        last if ($cur < 0);

        my $reverse_line = $self->get_line($fh, $index, $cur);
        last if !$reverse_line;

        my $reverse_snp = parse_dbsnp_line($reverse_line);
        $ds_start = $reverse_snp->{'ds_start'};

        if ($start == $ds_start) {
            push @backward, $reverse_line;
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
        my $snp = parse_dbsnp_line($line);
        my $ds_start = $snp->{'ds_start'};

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


sub parse_dbsnp_line {

    my ($line) = @_;

    my $snp = {};
    my @parts = split(/\t/,$line);

    my @keys = qw(
        ds_id
        ds_allele 
        ds_type
        ds_chr
        ds_start
        ds_stop
        ds_submitter
        rs_id
        strain
        is_validated
        is_validated_by_allele
        is_validated_by_cluster
        is_validated_by_frequency
        is_validated_by_hap_map
        is_validated_by_other_pop
    );

    my $i = 0;
    for my $key (@keys) {
        $snp->{$key} = $parts[$i];
        $i++;
    }

    return $snp;
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


