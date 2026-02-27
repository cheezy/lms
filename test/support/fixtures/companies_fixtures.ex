defmodule Lms.CompaniesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lms.Companies` context.
  """

  def unique_company_name, do: "company-#{System.unique_integer([:positive])}"

  def valid_company_attributes(attrs \\ %{}) do
    name = unique_company_name()

    Enum.into(attrs, %{
      name: name,
      slug: name
    })
  end

  def company_fixture(attrs \\ %{}) do
    {:ok, company} =
      attrs
      |> valid_company_attributes()
      |> Lms.Companies.create_company()

    company
  end
end
