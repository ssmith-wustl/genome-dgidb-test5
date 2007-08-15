
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
	my ($fh,$software,$build_id, $chr, $plus_minus, $begin, $end,
			$sample_id,$allele1,$allele2,$scores_ref) = @_;
	$build_id ||= 'B36';
	my (@scores) = @{$scores_ref};
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

#B36     C7      O+      55054249        55054249        H_FY-16530      'N 'N      polyscan2.2(N:N:)       polyphred6.0Beta(N:N:)  -
#B36     C7      O+      55054249        55054249        H_FY-16594      'T 'T      polyscan2.2(T:T:99)     polyphred6.0Beta(T:T:99_c99)    -
#B36     C7      O+      55054346        55054346        H_FY-17226      'N     'N       polyscan2.2(N:N:)       polyphred6.0Beta(N:N:)  -
#B36     C7      O+      55054346        55054346        H_FY-17228      'N     'N       polyscan2.2(N:N:)       polyphred6.0Beta(N:N:)  -

1;



