#! /gsc/bin/perl

use strict;
use warnings;

use Data::Dumper;
use DBI;
use IO::File;

my $fh = IO::File->new("< $ARGV[0]")
    or die "Can't open file ($ARGV[0]): $!";

my $dbh = DBI->connect('dbi:Oracle:dwrac', 'mguser', 'mguser_prd')
    or die "$DBI::errstr\n";
while ( my $line = $fh->getline )
{
    chomp $line;
    my @values = split(/\s+/, $line);
    my $sth = $dbh->prepare
    (
        sprintf
        (
            "select rgg.rgg_id from read_group_genotype rgg join chromosome c on c.chrom_id = rgg.chrom_id where c.chromosome_name = '%s' and rgg.start_ = '%s' and rgg.end = '%s' and rgg.allele1 = '%s' and rgg.allele2 = '%s' and rgg.allele1_type = '%s' and rgg.allele2_type = '%s' and rgg.num_reads1 = '%s' and rgg.num_reads2 = '%s'",
            @values,
        )
    )
        or die "$DBI::errstr\n";
    $sth->execute
        or die "$DBI::errstr\n";
    print $sth->fetchall_arrayref->[0]->[0],"\n";
}

$fh->close;
$dbh->disconnect;

exit 0;

=pod

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

