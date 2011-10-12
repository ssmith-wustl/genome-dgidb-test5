use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Temp;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

# Define some test classes so we can easily make dummy objects
package Genome::Data::Test;
use base 'Genome::Data';

sub create {
    my ($class, %params) = @_;
    my $self = {};
    bless ($self, $class);
    $self->foo($params{foo});
    $self->bar($params{bar});
    return $self;
}

sub foo {
    my ($self, $value) = @_;
    if ($value) {
        $self->{_foo} = $value;
    }
    return $self->{_foo};
}

sub bar {
    my ($self, $value) = @_;
    if ($value) {
        $self->{_bar} = $value;
    }
    return $self->{_bar};
}

package Genome::Data::Adaptor::Test;
use base 'Genome::Data::Adaptor';

sub parse_next_from_file {
    my $self = shift;
    my $fh = $self->_get_fh;
    my $line = $fh->getline;
    return unless $line;
    chomp $line;
    my ($foo, $bar) = split(",", $line);
    my $obj = Genome::Data::Test->create(
        foo => $foo,
        bar => $bar,
    );
    return $obj;
}

sub write_to_file {
    my ($self, @objs) = @_;
    my $fh = $self->_get_fh;
    for my $obj (@objs) {
        my @fields;
        push @fields, $obj->foo if $obj->foo;
        push @fields, $obj->bar if $obj->bar;
        $fh->print(join(",", @fields) . "\n");
    }
    return 1;
}

sub produces {
    return 'Genome::Data::Test';
}

# Test logic!
package main;

use_ok('Genome::Data::Sorter') or die;

# Make sure test data is in place, get output files ready
my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Data/';
ok(-d $test_data_dir, "test data dir exists at $test_data_dir") or die;

my $test_output_dir = '/gsc/var/cache/testsuite/running_testsuites/';
ok(-d $test_output_dir, "output dir exists at $test_output_dir") or die;

my $unsorted_input_file = $test_data_dir . 'test.csv.unsorted';
ok(-e $unsorted_input_file, "unsorted input file exists at $unsorted_input_file");

my $expected_output = $test_data_dir . 'test.csv';
ok(-e $expected_output, "expected output file exists at $expected_output");

my $generated_output_fh = File::Temp->new(
    DIR => $test_output_dir,
    TEMPLATE => 'genome-data-sorter-XXXXXXX',
);
my $generated_output = $generated_output_fh->filename;
$generated_output_fh->close;

# The only methods that aren't basic accessors/mutators are sort_by and sort. They're test below
# Test the sort_by method
my $sorter = {};
bless($sorter, 'Genome::Data::Sorter');
$sorter->input_file($unsorted_input_file);
$sorter->format('test');

my $rv = eval { $sorter->sort_by('blah') };
my $error = $@;
ok($error =~ /cannot be sorted by property/, 'could not set sort by to property that does not exist');

$rv = $sorter->sort_by('foo');
ok($rv, 'successfully set sort by to a property that does exist');

# Now create a legitimate sorter, have it do its thing, then check output against expected
$sorter = eval { Genome::Data::Sorter->create() };
$error = $@;
ok($error, 'could not produce sorter without parameters');

$sorter = eval {
    Genome::Data::Sorter->create(
        input_file => $unsorted_input_file,
        format => 'test',
        sort_by => 'foo',
    )
};
$error = $@;
ok($error =~ /Not given output file/, 'cannot create a sorter without an output file');

$sorter = eval {
    Genome::Data::Sorter->create(
        output_file => $generated_output,
        format => 'test',
        sort_by => 'foo',
    )
};
$error = $@;
ok($error =~ /Not given input file/, 'cannot create a sorter without an input file');

$sorter = eval {
    Genome::Data::Sorter->create(
        input_file => $unsorted_input_file,
        output_file => $generated_output,
        sort_by => 'foo',
    )
};
$error = $@;
ok($error =~ /Not given format/, 'cannot create a sorter without a format');

$sorter = eval {
    Genome::Data::Sorter->create(
        input_file => $unsorted_input_file,
        output_file => $generated_output,
        format => 'test',
    )
};
$error = $@;
ok($error =~ /Not given a property to sort by/, 'cannot create a sorter without a property to sort by');

$sorter = Genome::Data::Sorter->create(
    input_file => $unsorted_input_file,
    output_file => $generated_output,
    format => 'test',
    sort_by => 'foo',
);
ok($sorter, 'created sorter successfully');

$rv = $sorter->sort;
ok($rv, 'sorted successfully');

my $diff = `diff $generated_output $expected_output`;
ok(!$diff, "no diff between generated output $generated_output and expected output $expected_output");

done_testing();
