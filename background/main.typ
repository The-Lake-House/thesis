= Background

This chapter provides a brief overview of the components of the lakehouse architecture. It is by no means comprehensive, and highlights only a few key technologies that are relevant to understanding the constraints of lakehouse table formats.

There is no definitive lakehouse architecture @begoliLakehouseArchitectureManagement2021, but common key components such as a storage layer, a data management layer, and an execution layer @behmPhotonFastQuery2022. In this thesis we assume an architecture consisting of a storage system, storage formats, table formats, an execution engine, and a catalog as shown in @figure_lakehouse_architecture.

#figure(
  image("/_img/lakehouse_architecture.svg"),
  caption: [An overview of the components of the lakehouse architecture],
) <figure_lakehouse_architecture>

In the remainder of this chapter, we will first explore storage systems to learn about important constraints such as immutable files and consistency guarantees in @section_storage_systems. In @section_storage_formats, we introduce the structure and features of common storage formats, the raw data format used to persist table data. These data files are then joined into a table abstraction through the table formats described in @section_table_formats. Finally, we look at execution engines and learn how these tables can be queried in @section_execution_engines, and how table metadata such as a table's name and location is shared between execution engines in the form of a catalog in @section_catalogs.

#include "storage_systems.typ"

#include "storage_formats.typ"

#include "table_formats.typ"

#include "execution_engines.typ"

#include "catalogs.typ"
