#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 5;
use File::Slurp;

use above 'Genome';

BEGIN {
        use_ok('Genome::Model::Tools::Snp::GoldSnpIntersection');
    };

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Snp/GoldSnpIntersection';

my $gold_snp_file = "$dir/gold.snp";
my $maq_snp_file  = "$dir/maq.snp";
my $sam_snp_file  = "$dir/sam.snp";

my $exp_maq_report = read_file($dir.'/report.maq.ori');
my $exp_sam_report = read_file($dir.'/report.sam.ori');

=cut

my $maq_gsi = Genome::Model::Tools::Snp::GoldSnpIntersection->create(
    snp_file      => $maq_snp_file,
    gold_snp_file => $gold_snp_file,
);

isa_ok($maq_gsi,'Genome::Model::Tools::Snp::GoldSnpIntersection');

=cut

my $maq_report = `gt snp gold-snp-intersection --snp-file $maq_snp_file --gold-snp-file $gold_snp_file`;

ok($maq_report,'MAQ gold-snp-intersection execute ok');
is($maq_report, $exp_maq_report, 'MAQ gold-snp-intersection output matches the expected original one.');

=cut

my $sam_gsi = Genome::Model::Tools::Snp::GoldSnpIntersection->create(
    snp_file      => $sam_snp_file,
    gold_snp_file => $gold_snp_file,
    sam_format    => 1,
);

my $sam_report = $sam_gsi->execute;

=cut

my $sam_report = `gt snp gold-snp-intersection --snp-file $sam_snp_file --gold-snp-file $gold_snp_file --snp-format sam`;

ok($sam_report,'SAM gold-snp-intersection execute ok');
is($sam_report, $exp_sam_report, 'SAM gold-snp-intersection output matches the expected original one.');


exit;
