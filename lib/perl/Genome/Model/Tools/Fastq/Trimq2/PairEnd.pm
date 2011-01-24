package Genome::Model::Tools::Fastq::Trimq2::PairEnd;

use strict;
use warnings;

use Genome;
use File::Temp;
use File::Basename;

class Genome::Model::Tools::Fastq::Trimq2::PairEnd {
    is => 'Genome::Model::Tools::Fastq::Trimq2',
    has => [
        pair1_fastq_file  => {
            is  => 'Text',
            doc => 'the pair end fastq file 1',
        },
        pair2_fastq_file  => {
            is  => 'Text',
            doc => 'the pair end fastq file 2',
        },
    ],
    has_optional => [
        pair1_out_file    => {
            is  => 'Text',
            doc => 'the file path to use for the pair1 output file, default is xxx1.trimq2.fastq under same dir as pair1 fastq file',
        },
        pair2_out_file    => {
            is  => 'Text',
            doc => 'the file path to use for the pair2 output file, default is xxx2.trimq2.fastq under same dir as pair1 fastq file',
        },
        pair_as_frag_file => {
            is  => 'Text',
            doc => 'the file path to use for the pair as fragment fastq file, default is trimq2.pair_as_fragment.fastq under same dir as pair1 fastq file',
        },
    ],
};

sub help_synopsis {
    return <<EOS
gmt fastq trimq2 pair-end --pair1-fastq-file=lane1.fastq --pair1-out-file=lane1.trimmed.fastq

EOS
}

sub help_detail {
    return <<EOS 
Trims fastq reads with phred quality 2 as either Illumina quality string as B (quality value 66) or sanger quality string as # (quality value 35)
EOS
}


sub execute {
    my $self = shift;

    unless (-s $self->pair1_fastq_file and -s $self->pair2_fastq_file) {
        $self->error_message('Need both pair1 and pair2 fastq file');
        return;
    }
    
    my $out_dir = $self->output_dir;
    
    my $p1_fastq_file = $self->pair1_fastq_file;
    my $p2_fastq_file = $self->pair2_fastq_file;
    
    my ($p1_base_name, $p1_base_dir) = fileparse($p1_fastq_file);
    my ($p2_base_name, $p2_base_dir) = fileparse($p2_fastq_file);
    
    $p1_base_name =~ s/\.fastq$// if $p1_base_name =~ /\.fastq$/;
    $p2_base_name =~ s/\.fastq$// if $p2_base_name =~ /\.fastq$/;

    $self->error_message("pair1 and 2 fastq file are not in the same directory") and return
        unless $p1_base_dir eq $p2_base_dir;
    $out_dir ||= $p1_base_dir;

    my $p1_in_fh = Genome::Sys->open_file_for_reading($p1_fastq_file);
    unless ($p1_in_fh) {
        $self->error_message('Failed to open fastq file ' . $p1_fastq_file . ": $!");
        return;
    }
    binmode $p1_in_fh, ":utf8";

    my $p2_in_fh = Genome::Sys->open_file_for_reading($p2_fastq_file);
    unless ($p2_in_fh) {
        $self->error_message('Failed to open fastq file ' . $p2_fastq_file . ": $!");
        return;
    }
    binmode $p2_in_fh, ":utf8";
    
    #my $p1_filter_file = $out_dir . "/$p1_base_name.trimq2.filtered.fastq";
    #my $p2_filter_file = $out_dir . "/$p2_base_name.trimq2.filtered.fastq";
    my $pair_filter_file = $out_dir . '/trimq2.pair_end.filtered.fastq'; 
    my $frag_filter_file = $out_dir . '/trimq2.pair_as_fragment.filtered.fastq';

    my $p1_out_file = $self->pair1_out_file || $out_dir ."/$p1_base_name.trimq2.fastq";
    my $p2_out_file = $self->pair2_out_file || $out_dir ."/$p2_base_name.trimq2.fastq";

    $self->pair1_out_file($p1_out_file);
    $self->pair2_out_file($p2_out_file);

    my $p1_out_fh = Genome::Sys->open_file_for_writing($p1_out_file);
    unless ($p1_out_fh) {
        $self->error_message('Failed to open output file ' . $p1_out_file . ": $!");
        return;
    }
    binmode $p1_out_fh, ":utf8";

    my $p2_out_fh = Genome::Sys->open_file_for_writing($p2_out_file);
    unless ($p2_out_fh) {
        $self->error_message('Failed to open output file ' . $p2_out_file . ": $!");
        return;
    }
    binmode $p2_out_fh, ":utf8";

    my $pair_filter_fh = Genome::Sys->open_file_for_writing($pair_filter_file);
    unless ($pair_filter_fh) {
        $self->error_message('Failed to open filtered file '. $pair_filter_file . ": $!");
        return;
    }
    binmode $pair_filter_fh, ":utf8";

    my $frag_filter_fh = Genome::Sys->open_file_for_writing($frag_filter_file);
    unless ($frag_filter_fh) {
        $self->error_message('Failed to open filtered file '. $frag_filter_file . ": $!");
        return;
    }
    binmode $frag_filter_fh, ":utf8";

    my $report = $self->report_file || $out_dir . '/trimq2.report';
    if (-e $report) {
        $self->warning_message("$report already exist. Now remove it");
        unlink $report;
    }
    
    my $report_fh = Genome::Sys->open_file_for_writing($report);
    unless ($report_fh) {
        $self->error_message("Failed to open report file " . $report . ": $!");
        return;
    }
    binmode $report_fh, ":utf8";

    my $frag_fastq = $self->pair_as_frag_file || $out_dir . '/trimq2.pair_as_fragment.fastq';
    $self->pair_as_frag_file($frag_fastq);

    if (-e $frag_fastq) {
        $self->warning_message("$frag_fastq already exist. Now remove it");
        unlink $frag_fastq;
    }
    my $frag_fh = Genome::Sys->open_file_for_writing($frag_fastq);
    unless ($frag_fh) {
        $self->error_message('Failed to open ' . $frag_fastq . ": $!");
        return;
    }
    binmode $frag_fh, ":utf8";

    my $ori_ct    = 0;
    my $trim_ct   = 0;
    my $filter_ct = 0;

    my $rd_ori_ct       = 0;
    my $rd_trim_ct      = 0;
    my $rd_filter_ct    = 0; 
    my $rd_pair_frag_ct = 0;
    
    my $qual_str = $self->trim_string;
    
    while (my $p1_header = $p1_in_fh->getline) {
        my $seq1  = $p1_in_fh->getline;
        my $sep1  = $p1_in_fh->getline;
        my $qual1 = $p1_in_fh->getline;

        my ($clean_header1) = $p1_header =~ /^@(\S+)\s+/;
        my $pair_basename1;
        
        if ($clean_header1 =~ /^(\S+)[12]$/) {
            $pair_basename1 = $1;
        }
        else {
            $self->error_message("Header $p1_header in $p1_fastq_file does not end with 1 or 2, not pair end data");
            return;
        }
        
        my $p2_header = $p2_in_fh->getline;
        my $seq2  = $p2_in_fh->getline;
        my $sep2  = $p2_in_fh->getline;
        my $qual2 = $p2_in_fh->getline;
    
        my ($clean_header2) = $p2_header =~ /^@(\S+)\s+/;
        my $pair_basename2;
        
        if ($clean_header2 =~ /^(\S+)[12]$/) {
            $pair_basename2 = $1;
        }
        else {
            $self->error_message("Header $p2_header in $p2_fastq_file does not end with 1 or 2, not pair end data");
            return;
        }

        unless ($pair_basename1 eq $pair_basename2) {
            $self->error_message("pair basename are different between pair 1 and 2: $pair_basename1 and $pair_basename2");
            return;
        }
        
        my $seq_length1 = (length $seq1) - 1; #account for new line
        my $seq_length2 = (length $seq2) - 1; #account for new line

        $ori_ct += $seq_length1 + $seq_length2;
        $rd_ori_ct += 2;

        if ($qual1 =~ /$qual_str/ and $qual2 =~ /$qual_str/) {
            my ($trim_qual1) = $qual1 =~ /^(\S*?)$qual_str/;
            my $trim_length1 = length $trim_qual1;

            my ($trim_qual2) = $qual2 =~ /^(\S*?)$qual_str/;
            my $trim_length2 = length $trim_qual2;

            if ($trim_length1 >= $self->length_limit) {
                my $trimmed_length1 = $seq_length1 - $trim_length1;
                
                if ($trim_length2 >= $self->length_limit) {
                    my $trimmed_length2 = $seq_length2 - $trim_length2;
                    
                    $p1_out_fh->print($p1_header, substr($seq1, 0, $trim_length1)."\n", $sep1, $trim_qual1."\n"); 
                    $p2_out_fh->print($p2_header, substr($seq2, 0, $trim_length2)."\n", $sep2, $trim_qual2."\n"); 

                    $report_fh->print($clean_header1."\tT\t".$trimmed_length1."\n");  #In report T for trimmed
                    $report_fh->print($clean_header2."\tT\t".$trimmed_length2."\n");  #In report T for trimmed

                    $trim_ct += $trimmed_length1 + $trimmed_length2;
                    $rd_trim_ct += 2;
                }
                else {
                    $frag_filter_fh->print($p2_header, $seq2, $sep2, $qual2);
                    $report_fh->print($clean_header2."\tF\t".$seq_length2."\n");  #In report F for filtered
                    $filter_ct += $seq_length2;
                    $rd_filter_ct++;  
                    
                    $frag_fh->print($p1_header, substr($seq1, 0, $trim_length1)."\n", $sep1, $trim_qual1."\n"); 
                    $report_fh->print($clean_header1."\tPF\t".$trimmed_length1."\n");  #In report PF for pair-end-as-fragment
                    $rd_pair_frag_ct++;

                    $trim_ct += $trimmed_length1;
                    $rd_trim_ct++;
                }
            }
            else {
                #$p1_filter_fh->print($p1_header, $seq1, $sep1, $qual1);
                $report_fh->print($clean_header1."\tF\t".$seq_length1."\n");  #In report F for filtered
                $filter_ct += $seq_length1;
                $rd_filter_ct++;  

                if ($trim_length2 >= $self->length_limit) {
                    $frag_filter_fh->print($p1_header, $seq1, $sep1, $qual1);
                    my $trimmed_length2 = $seq_length2 - $trim_length2;
                    
                    $frag_fh->print($p2_header, substr($seq2, 0, $trim_length2)."\n", $sep2, $trim_qual2."\n"); 
                    $report_fh->print($clean_header2."\tPF\t".$trimmed_length2."\n");  #In report PF for pair-end-as-fragment
                    $rd_pair_frag_ct++;

                    $trim_ct += $trimmed_length2;
                    $rd_trim_ct++;
                }
                else {
                    $pair_filter_fh->print($p1_header, $seq1, $sep1, $qual1);
                    $pair_filter_fh->print($p2_header, $seq2, $sep2, $qual2);
                    $report_fh->print($clean_header2."\tF\t".$seq_length2."\n");  #In report F for filtered
                    $filter_ct += $seq_length2;
                    $rd_filter_ct++;  
                }
            }
        }
        elsif ($qual1 =~ /$qual_str/) {
            my ($trim_qual1) = $qual1 =~ /^(\S*?)$qual_str/;
            my $trim_length1 = length $trim_qual1;

            if ($trim_length1 >= $self->length_limit) {
                my $trimmed_length1 = $seq_length1 - $trim_length1;
                $p1_out_fh->print($p1_header, substr($seq1, 0, $trim_length1)."\n", $sep1, $trim_qual1."\n"); 
                $report_fh->print($clean_header1."\tT\t".$trimmed_length1."\n");  #In report T for trimmed
                
                $trim_ct += $trimmed_length1;
                $rd_trim_ct++;

                $p2_out_fh->print($p2_header, $seq2, $sep2, $qual2);
            }
            else {
                $frag_filter_fh->print($p1_header, $seq1, $sep1, $qual1);
                $report_fh->print($clean_header1."\tF\t".$seq_length1."\n");  #In report F for filtered
                $filter_ct += $seq_length1;
                $rd_filter_ct++;

                $frag_fh->print($p2_header, $seq2, $sep2, $qual2); 
                $report_fh->print($clean_header2."\tPF\t".$seq_length2."\n");  #In report PF for pair-end-as-fragment
                $rd_pair_frag_ct++;
            }
        }
        elsif ($qual2 =~ /$qual_str/) {
            my ($trim_qual2) = $qual2 =~ /^(\S*?)$qual_str/;
            my $trim_length2 = length $trim_qual2;

            if ($trim_length2 >= $self->length_limit) {
                my $trimmed_length2 = $seq_length2 - $trim_length2;
                $p2_out_fh->print($p2_header, substr($seq2, 0, $trim_length2)."\n", $sep2, $trim_qual2."\n"); 
                $report_fh->print($clean_header2."\tT\t".$trimmed_length2."\n");  #In report T for trimmed
                
                $trim_ct += $trimmed_length2;
                $rd_trim_ct++;

                $p1_out_fh->print($p1_header, $seq1, $sep1, $qual1);
            }
            else {
                $frag_filter_fh->print($p2_header, $seq2, $sep2, $qual2);
                $report_fh->print($clean_header2."\tF\t".$seq_length2."\n");  #In report F for filtered
                $filter_ct += $seq_length2;
                $rd_filter_ct++;

                $frag_fh->print($p1_header, $seq1, $sep1, $qual1); 
                $report_fh->print($clean_header1."\tPF\t".$seq_length1."\n");  #In report PF for pair-end-as-fragment
                $rd_pair_frag_ct++;
            }
        }
        else {
            $p1_out_fh->print($p1_header, $seq1, $sep1, $qual1);
            $p2_out_fh->print($p2_header, $seq2, $sep2, $qual2);
        }
    }

    $frag_fh->close;
    $p1_in_fh->close;
    $p2_in_fh->close;
    $p1_out_fh->close;
    $p2_out_fh->close;
    $pair_filter_fh->close;
    $frag_filter_fh->close;

    $report_fh->print("\nSummary:\n");
    my $rd_new_ct  = $rd_ori_ct - $rd_filter_ct;
    #my $rd_percent = 100*$rd_new_ct/$rd_ori_ct;
    my $new_ct  = $ori_ct - $trim_ct - $filter_ct;
    my $percent = 100*$new_ct/$ori_ct;
       
    $report_fh->print("\nNumberOfOriginalReads  NumberOfTrimmedReads  NumberOfFilteredReads  NumberOfRemainingReads  NumberOfPairAsFragmentReads\n");
    $report_fh->printf("%21s%22s%23s%24s%12s\n", $rd_ori_ct, $rd_trim_ct, $rd_filter_ct, $rd_new_ct, $rd_pair_frag_ct);
    $report_fh->print("\nNumberOfOriginalBases  NumberOfTrimmedBases  NumberOfFilteredBases  NumberOfResultingBases  Percentage\n");
    $report_fh->printf("%21s%22s%23s%24s%11.1f%%\n", $ori_ct, $trim_ct, $filter_ct, $new_ct, $percent);
    $report_fh->close;
    
    return 1;
}

1;

