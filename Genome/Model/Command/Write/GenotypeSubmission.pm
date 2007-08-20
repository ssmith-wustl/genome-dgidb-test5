
package Genome::Model::Command::Write::GenotypeSubmission;

use strict;
use warnings;

use UR;
use Command;
use IO::File;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "export data into a genotype submisssion file format"
}

sub help_synopsis {
    return <<"EOS"

Write a subclass of this.  

Give it a name which is an extension of this class name.

Implement a new writing out for some part  of a genome model.

EOS
}

sub help_detail {
    return <<"EOS"

This module is an base class for commands that export data into the genotype submission file format.

Subclasses will implement different input formats.  This module
should handle common parameters, typically for handling the output file. 

EOS
}

sub Open {
	my ($basename) = @_;
	my $fh = new IO::File;
	my $genotype_submission_file = $basename . '_genotype_submission.tsv';
	unless ($fh->open(">$genotype_submission_file")) {
		return undef;
	}
	return $fh;
}

sub Write {
	my ($fh,$software,$build, $chr, $plus_minus, $begin, $end,
			$sample_id,$allele1,$allele2,$scores_ref, $number) = @_;
	$build ||= '36';
	my (@scores) = @{$scores_ref};
	my $build_id = 'B' . $build;
	my $chromosome = 'C' . $chr;
	my $orientation = 'O' . $plus_minus;
	my $seq1 = "'" . $allele1;
	my $seq2 = "'" . $allele2;
	my @main = ($build_id, $chromosome, $orientation, $begin, $end, $sample_id,
							$seq1, $seq2);
	my @alleles = ($allele1, $allele2);
	my $comment = $software . '(' . join(':',(join(':',@alleles),join(':',@scores))) . ')';
	my @comments;
	push @comments, ($comment);
	my $line = join("\t",(@main, @comments)) . "\n";
	print $fh $line;
}

#  The main data structure is implemented according to the following example.
#
#     $mutation = {
#        H_FY-16530 => {
#           746938 => {
#              build => 36,
#              chromosome => 18,
#              genotype => "C C",
#              end => 746939,
#              calls => ["polyscan2.2 G G 99", "polyphred6.0Beta G G 99"],
#              file_line_num => 34234,
#           },
#           746920 => {
#              :
#           },
#        },
#        H_FY-16594 => {
#           :
#        },
#        :
#     };

sub AddMutation {
	my ($mutation,$software,$build, $chr, $plus_minus, $begin, $end,
			$sample_id, $allele1, $allele2, $scores_ref, $number) = @_;
	$build ||= '36';

	my @alleles = ($allele1, $allele2);
	my (@scores) = @{$scores_ref};
	my $call = $software . ' ' . join(' ',(join(' ',@alleles),join(' ',@scores)));
	my $calls;
	push @{$calls}, ($call);
	$mutation->{$sample_id}->{$begin} = {
																				 'build' => $build,
																				 'chromosome' => $chr,
																				 'genotype' => join(' ',@alleles),
																				 'end' => $end,
																				 'calls' => $calls,
																				 'file_line_num' => $number
																				};
	return $mutation;
}

1;



