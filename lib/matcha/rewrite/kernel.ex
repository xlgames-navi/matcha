defmodule Matcha.Rewrite.Kernel do
  @moduledoc """
  Replacements for Kernel functions when rewriting Elixir into match specs.

  These are versions that play nicer with Erlang's match spec limitations.
  """

  # Keep up to date with the imports in Matcha.Rewrite's expand_spec_ast
  import Kernel,
    except: [
      and: 2,
      elem: 2,
      is_boolean: 1,
      is_exception: 1,
      is_exception: 2,
      is_map_key: 2,
      is_struct: 1,
      is_struct: 2,
      or: 2
    ]

  @doc """
  Re-implements `Kernel.and/2`.

  This ensures that Elixir 1.6.0+'s [boolean optimizations](https://github.com/elixir-lang/elixir/commit/25dc8d8d4f27ca105d36b06f3f23dbbd0b823fd0)
  don't create (disallowed) case statements inside match spec bodies.
  """
  defmacro left and right do
    quote do
      :erlang.andalso(unquote(left), unquote(right))
    end
  end

  @doc """
  Re-implements `Kernel.is_boolean/1`.

  The original simply calls out to `:erlang.is_boolean/1`,
  which is not allowed in match specs (as of Erlang/OTP 25).
  Instead, we re-implement it in terms of things that are.

  See: https://github.com/erlang/otp/issues/7045
  """

  # TODO: Once Erlang/OTP 26 is the minimum supported version,
  #  we can remove this from Matcha.Rewrite.Kernel,
  #  as that is when support in match specs was introduced. See:
  #  https://github.com/erlang/otp/pull/7046

  defmacro is_boolean(value) do
    quote do
      unquote(value) == true or unquote(value) == false
    end
  end

  @doc """
  Re-implements `Kernel.is_exception/1`.

  This borrows the guard-specific implementation [from Elixir](https://github.com/elixir-lang/elixir/blob/6730d669fb319411f8e411d4126f1f4067ef9231/lib/elixir/lib/kernel.ex#L2494-L2499)
  since what Elixir wants to do in normal bodies is invalid in match specs.
  """
  defmacro is_exception(term) do
    quote do
      is_map(unquote(term)) and :erlang.is_map_key(:__struct__, unquote(term)) and
        is_atom(:erlang.map_get(:__struct__, unquote(term))) and
        :erlang.is_map_key(:__exception__, unquote(term)) and
        :erlang.map_get(:__exception__, unquote(term)) == true
    end
  end

  @doc """
  Re-implements `Kernel.is_exception/2`.

  This borrows the guard-specific implementation [from Elixir](https://github.com/elixir-lang/elixir/blob/6730d669fb319411f8e411d4126f1f4067ef9231/lib/elixir/lib/kernel.ex#L2538-L2545)
  since what Elixir wants to do in normal bodies is invalid in match specs.
  """
  defmacro is_exception(term, name) do
    quote do
      is_map(unquote(term)) and
        (is_atom(unquote(name)) or :fail) and
        :erlang.is_map_key(:__struct__, unquote(term)) and
        :erlang.map_get(:__struct__, unquote(term)) == unquote(name) and
        :erlang.is_map_key(:__exception__, unquote(term)) and
        :erlang.map_get(:__exception__, unquote(term)) == true
    end
  end

  @doc """
  Re-implements `Kernel.is_struct/1`.

  This borrows the guard-specific implementation [from Elixir](https://github.com/elixir-lang/elixir/blob/6730d669fb319411f8e411d4126f1f4067ef9231/lib/elixir/lib/kernel.ex#L2414-L2417)
  since what Elixir wants to do in normal bodies is invalid in match specs.
  """
  defmacro is_struct(term) do
    quote do
      is_map(unquote(term)) and :erlang.is_map_key(:__struct__, unquote(term)) and
        is_atom(:erlang.map_get(:__struct__, unquote(term)))
    end
  end

  @doc """
  Re-implements `Kernel.is_struct/2`.

  This borrows the guard-specific implementation [from Elixir](https://github.com/elixir-lang/elixir/blob/6730d669fb319411f8e411d4126f1f4067ef9231/lib/elixir/lib/kernel.ex#L2494-L2499)
  since what Elixir wants to do in normal bodies is invalid in match specs.
  """
  defmacro is_struct(term, name) do
    quote do
      is_map(unquote(term)) and
        (is_atom(unquote(name)) or :fail) and
        :erlang.is_map_key(:__struct__, unquote(term)) and
        :erlang.map_get(:__struct__, unquote(term)) == unquote(name)
    end
  end

  @doc """
  Re-implements `Kernel.or/2`.

  This ensures that Elixir 1.6.0+'s [boolean optimizations](https://github.com/elixir-lang/elixir/commit/25dc8d8d4f27ca105d36b06f3f23dbbd0b823fd0)
  don't create (disallowed) case statements inside match spec bodies.
  """
  defmacro left or right do
    quote do
      :erlang.orelse(unquote(left), unquote(right))
    end
  end

  @doc """
  Re-implements `Kernel.elem/2`.

  Elixir 1.20 stopped inlining `elem/2` to `:erlang.element/2` during macro
  expansion in body contexts. We inline it explicitly here so match specs can
  use it regardless of Elixir version.
  """
  defmacro elem(tuple, index) when is_integer(index) do
    erlang_index = index + 1
    quote do
      :erlang.element(unquote(erlang_index), unquote(tuple))
    end
  end

  @doc """
  Re-implements `Kernel.is_map_key/2`.

  Elixir 1.20 stopped inlining `is_map_key/2` to `:erlang.is_map_key/2` during
  macro expansion in body contexts. We inline it explicitly here, also swapping
  the argument order: Elixir's `is_map_key(map, key)` vs Erlang's
  `:erlang.is_map_key(key, map)`.
  """
  defmacro is_map_key(map, key) do
    quote do
      :erlang.is_map_key(unquote(key), unquote(map))
    end
  end
end
