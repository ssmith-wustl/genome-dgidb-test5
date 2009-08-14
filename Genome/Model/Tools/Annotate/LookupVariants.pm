
package Genome::Model::Tools::Annotate::LookupVariants;

use strict;
use warnings;

use Genome;
use Data::Dumper;


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
        dbSNP_path => {
            type     => 'Text',
            is_input => 1,
            default  => '/gscmnt/sata835/info/medseq/imported_variations/dbSNP/130/',
            doc      => "path to dbSNP files broken into chromosome",
        },
        index_fixed_width => {
            type     => 'Int',
            is_input => 1,
            default  => 10,
            doc      => "look, dont change this, ok?"
        },
    ],
    has_optional => [
        report_mode => {
            type     => 'Text',
            is_input => 1,
            default  => 'novel-only',
            doc      =>
                'novel-only (DEFAULT VALUE) prints lines from variant_file that are not found in dbSNP
                    known-only prints lines from variant file that are found in dbSNP',
        },
        print_dbsnp_matches => {
            type     => 'Boolean',
            is_input => 1,
            default  => 0,
            doc      => 'print matching dbSNP line isntead of input',
        },
        no_headers => {
            type     => 'Boolean',
            is_input => 1,
            default  => 0,
            doc      => 'Exclude headers from output',
        },
        filter_out_submitters => {
            type     => 'Text',
            is_input => 1,
            doc      =>
                'Comma separated (no spaces allowed) list of submitters to IGNORE from dbsnp',
        },
    ],
};


sub help_synopsis { 
    return <<EOS
gt annotate lookup-variants --variant-file snvs.csv --output-file novel_variants.csv
EOS
}

sub help_detail {
    return <<EOS
By default, takes in a file of variants and filters out variants that are already known to exist.
EOS
}

sub execute { 

    my ($self) = @_;

    my $variant_file = $self->variant_file;
    open(my $in, $variant_file) || die "cant open $variant_file";
    
    while (my $line = <$in>) {

        if ($self->filter_out_submitters) {
            $self->print_input_lines_with_filters($line);
        } else {
            $self->print_input_lines_without_filters($line);
        }
    }

    close($in);

    return 1;
}

sub print_input_lines_with_filters {

    my ($self, $line) = @_;

    my @matches = $self->find_all_matches($line);

    @matches = map { $self->filter_by_submitters($_) } @matches;
    @matches = map { $self->filter_by_type($_) } @matches; 

    print $line if @matches;
}

sub print_input_lines_without_filters {

    my ($self, $line) = @_;

    my $pos = $self->find_a_matching_pos($line);
    my $report_mode = $self->report_mode();

    if ($report_mode eq 'novel-only' && !$pos) {
        print $line;
    }
    
    if ($report_mode eq 'known-only' && $pos) {
        print $line;
    }
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
    if ($pos) {
        my ($chr, $start, $stop) = split(/\t/,$line);
        @matches = $self->find_matches_around($chr, $pos);
    }

    return @matches;
}

sub find_matches_around {

    my ($self, $chr, $pos) = @_;
    my $variant = {};
    my (@forward, @backward);
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

    my ($fh, $index) = $self->get_fh_for_chr($chr);
    my $match_count = 0;
    my $size = <$index>; chomp($size);  
    my $min = 0;
    my $max = $size - 1;

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

    my $dbSNP_path = $self->dbSNP_pathname();
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

sub print_db_snp_lines_without_filters {
    
    my ($self, $line) = @_;

    my $report_mode = $self->report_mode();
    my @matches = $self->find_all_matches($line);

    if ( $report_mode eq 'novel-only' && !@matches ) {
        print $line;
    }

    my $group_by_position = $self->group_by_position();
    if ( $report_mode eq 'known_only' ) {

        if ($group_by_position) {
            # novel-only is automatically group by position, yeah?
            @matches= $self->group_variants_by_position(\@matches);            
        }

        print $_ for @matches;
    }

    return 1;
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

    $ gt annotate lookup-variants --variant-file snvs.csv --output-file novel_variants.csv
 
=cut


