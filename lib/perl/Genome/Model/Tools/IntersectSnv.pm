package Genome::Model::Tools::IntersectSnv;

use warnings;
use strict;

use Genome;
use Genome::Info::IUB;
use JSON;
use Sort::Naturally;

class Genome::Model::Tools::IntersectSnv {
    is => 'Genome::Command::Base',
    has_input => {
        snvs_a_path => {
            is => 'File',
        },
        snvs_b_path => {
            is => 'File',
        },
    },
    has_transient_optional => {
        report_json => {
            is_input => 0,
            is => 'Text'
        },
    }
};

sub column_count {
    my ($self, $file) = @_;
    my $fh = Genome::Sys->open_file_for_reading($file);
    my $count = 0;
    while (<$fh>) {
        next if /^$/ or /^#/;
        my @fields = split("\t");
        $count = scalar @fields;
        last;
    }
    $fh->close;
    return $count;
}

sub zygosity {
    return (shift =~ /^[ACGT]$/) ? "homozygous" : "heterozygous";
}

sub overlap {
    my ($bases_hash_a, $bases_hash_b) = @_;
    my $count = 0;
    for my $c (keys %$bases_hash_a) {
        ++$count if defined $bases_hash_b->{$c};
    }
    return $count;
}

sub iub_unique {
    my $iub = shift;
    $iub = Genome::Info::IUB->iub_to_string($iub);
    return map { $_ => 1 } split('', $iub);
}

sub describe_snv {
    my $snv = shift;
    my ($ref, $call) = split('/', $snv->[3]);
    my $category = 'ambiguous call';
    my $detail =  'ambiguous call';

    my $zygosity = zygosity($call);

    if ($call eq $ref) {
        $category = "$zygosity reference";
        $detail = undef;
    } elsif ($zygosity eq "homozygous") {
        $category = "$zygosity";
        $detail = undef;
    } else {
        my %bases_ref = iub_unique($ref);
        my %bases_call = iub_unique($call);
        my $overlap = overlap(\%bases_ref, \%bases_call);
        my $call_base_count = scalar keys %bases_call;
        my $variant_alleles = $call_base_count - $overlap;
        
        if ($call_base_count == 3) {
            $category = "tri-allelic";
            $detail = ($overlap?'with':'no') . ' reference';
        } else { 
            $category = "$zygosity";
            $detail = "$variant_alleles allele";
        }
    }

    return (category => $category, detail => $detail);
}

sub compare_snvs {
    my ($snv_a, $snv_b) = @_;
    my ($ref_a, $call_a) = split('/', $snv_a->[3]);
    my ($ref_b, $call_b) = split('/', $snv_b->[3]);

    if ($ref_a ne $ref_b) {
        return 'reference mismatch';
    } elsif ($call_a eq $call_b) {
        return 'match';
    } else {
        my $iub_a = Genome::Info::IUB->iub_to_string($call_a);
        my $iub_b = Genome::Info::IUB->iub_to_string($call_b);
        for my $c (split('', $iub_a)) {
            return 'partial match' if index($iub_b, $c) != -1;
        }
        return 'mismatch';
    }
}

sub calculate_metrics {
    my ($intersect_fh, $columns_in_a) = @_;

    my %results;
    while (my $line = <$intersect_fh>) {
        chomp $line;
        my @flds = split("\t", $line);
        my @snv_a = @flds[0..($columns_in_a-1)];
        my @snv_b = @flds[$columns_in_a..$#flds];
        process_intersection(\@snv_a, \@snv_b, \%results);
    }
    return %results;
}

sub count_snv_a {
    my ($snv_a, $results) = @_;
    my %snv_desc_a = describe_snv($snv_a);
    ++$results->{$snv_desc_a{category}}{total};
}

sub process_intersection {
    my ($snv_a, $snv_b, $results) = @_;
    my $cmp = compare_snvs($snv_a, $snv_b);
    my %snv_desc_a = describe_snv($snv_a);
    my %snv_desc_b = describe_snv($snv_b);
    my $desc_b = "$snv_desc_b{category}";
    $desc_b .= " - $snv_desc_b{detail}" if defined $snv_desc_b{detail};
    ++$results->{$snv_desc_a{category}}{hits}{$cmp}{$desc_b}{count};
    $results->{$snv_desc_a{category}}{hits}{$cmp}{$desc_b}{qual} += $snv_b->[4];
}

sub compare_position {
    my ($snv_a, $snv_b) = @_;
    for my $i (0..2) {
        my $cmp = ncmp($snv_a->[$i], $snv_b->[$i]);
        return $cmp if $cmp != 0;
    }
    return 0;
}

sub next_snv {
    my $fh = shift;
    my $line;
    do {
        $line = <$fh>;
        chomp $line;
    } while (!$fh->eof and ($line eq '' or $line =~ /^#/));
    return if $line eq '';
    my @snv = split("\t", $line);
    return \@snv;
}

sub intersect {
    my ($fh_a, $fh_b) = @_;

    my %results;
    my $snv_a = next_snv($fh_a);
    count_snv_a($snv_a, \%results);
    my $snv_b = next_snv($fh_b);
    while (!$fh_a->eof() && !$fh_b->eof()) {
        my $cmp = compare_position($snv_a, $snv_b);
        if ($cmp < 0) {
            $snv_a = next_snv($fh_a);
            count_snv_a($snv_a, \%results);
        } elsif ($cmp > 0) {
            $snv_b = next_snv($fh_b);
        } else { # hit
            process_intersection($snv_a, $snv_b, \%results);
            # don't advance A to allow for repeats in B
            $snv_b = next_snv($fh_b);
        }
    }

    while (!$fh_a->eof()) {
        $snv_a = next_snv($fh_a);
        count_snv_a($snv_a, \%results);
    }

    return %results;
}

sub execute {
    my $self = shift;
    my $fh_a = Genome::Sys->open_file_for_reading($self->snvs_a_path);
    my $fh_b = Genome::Sys->open_file_for_reading($self->snvs_b_path);

#    my %results = calculate_metrics($intersect_fh, $columns_in_a);
    my %results = intersect($fh_a, $fh_b);

    $self->report_json(format_results_json(\%results));
    print $self->report_json; 
}

sub format_results_json {
    return to_json(shift, {ascii=>1});
}

sub format_results_html {
    my $results = shift;

    my $html = <<EOS
<style type="text/css">
    .snv_category_head {
        background-color: #eeeeee;
        font-weight: bold;
        font-size: 1.1em;
        border-top: solid 2px black;
        border-bottom: solid 1px #aaaaaa;
    }
    .snv_category_flds {
        text-align: right;
        background-color: #eeeeee;
        border-bottom: solid 1px #aaaaaa;
    }
    .match_type {
        font-weight: bold;
        font-size: 1.1em;
        font-style: normal;
        border-bottom: solid 1px black;
        background-color: #eeeeee;
    }
    .hit_detail {
        text-align: right;
        padding-left: 20px;
    }
    table.snv {
        font-size: 80%;
        border-collapse: collapse;
    }
    table.snv td {
        vertical-align: bottom;
    }
</style>
EOS
;
    $html .= "<table class=\"snv\">\n";
    for my $a_type (keys %$results) {
        next if scalar keys %{$results->{$a_type}{hits}} == 0;
        my $total = $results->{$a_type}{total}; 
        my $uc_a_type = join(" ", map { ucfirst($_) } split(" ", $a_type));
        $html .= "<tr><td class=\"snv_category_head\">$uc_a_type</td>\n";
        $html .= "<td class=\"snv_category_head\" colspan=\"3\">$total</td></tr>\n";
        $html .= "<tr class=\"snv_category_flds\">\n";
        $html .= "<td>&nbsp;</td>\n";
        $html .= "<td>SNV Count</td>\n";
        $html .= "<td>%</td>\n";
        $html .= "<td>Mean Quality<br>(Certainty%)</td>\n";
        $html .= "</tr>\n";
        for my $match_type (keys %{$results->{$a_type}{hits}}) {
            my $uc_match_type = join(" ", map { ucfirst($_) } split(" ", $match_type));
            $html .= "<tr><td class=\"match_type\" colspan=\"4\">$uc_match_type</td></tr>\n";
            for my $b_type (keys %{$results->{$a_type}{hits}{$match_type}}) {
                $html .= "<tr>\n";
                my $count = $results->{$a_type}{hits}{$match_type}{$b_type}{count};
                my $qual  = $results->{$a_type}{hits}{$match_type}{$b_type}{qual};
                my $percent = sprintf "%.02f", 100*$count / $total; 
                my $mean_qual = sprintf "%.02f", $qual / $count;
                my $mean_confidence = sprintf "%.02f", 100*(1-exp(log(10)*$mean_qual/-10));
                $html .= "<td class=\"hit_detail\">$b_type</td>\n";
                $html .= "<td class=\"hit_detail\">$count</td>\n";
                $html .= "<td class=\"hit_detail\">$percent</td>\n";
                $html .= "<td class=\"hit_detail\">$mean_qual ($mean_confidence%)</td>\n";
                $html .= "</tr>\n";
            }
        }
    }
    $html .= "</table>\n";
     
    return $html;
}

1;
