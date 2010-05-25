
package Genome::Model::Tools::LSFSpool::Errors;

use Exception::Class (
  "Genome::Model::Tools::LSFSpool::Error",
  "Genome::Model::Tools::LSFSpool::Errors" =>
    { isa => "Genome::Model::Tools::LSFSpool::Error" },
  "Genome::Model::Tools::LSFSpool::Errors::Recoverable" =>
    { isa => "Genome::Model::Tools::LSFSpool::Error" },
  "Genome::Model::Tools::LSFSpool::Errors::Fatal" =>
    { isa => "Genome::Model::Tools::LSFSpool::Error" },
);

1;
