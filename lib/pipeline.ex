defmodule Pipeline do
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [pipe: 1, pipe: 2, pipe: 3, pipeline: 1]
      @before_compile unquote(__MODULE__)
      Module.register_attribute __MODULE__, :pipes, accumulate: true
      Module.register_attribute __MODULE__, :pipelines, accumulate: true
    end
  end

  defmacro __before_compile__(env) do
    define_pipeline(Module.get_attribute(env.module, :pipes))
  end

  defmacro pipe(arg1, arg2 \\ nil, arg3 \\ nil) do
    args = [arg1, arg2, arg3]
    |> Enum.filter(&(!is_nil &1))

    quote do: @pipes unquote(args)
  end

  defmacro pipeline(module) do
    quote do: @pipes unquote(module)
  end

  defp define_pipeline(pipes) do
    quote do
      def pipe_through(var!(input)) do
        unquote(build_pipeline(Enum.reverse pipes))
      end
    end
  end

  defp build_pipeline([]) do
    quote do
      {:ok, var!(input)}
    end
  end

  defp build_pipeline([pipe | rest]) do
    quote do
      var!(func) = unquote(get_pipe_func(pipe))
      case var!(func).(var!(input)) do
        {:ok, var!(input)} ->
          unquote(build_pipeline(rest))
        {:error, message} -> {:error, message}
        var!(input) -> unquote(build_pipeline(rest))
      end
    end
  end

  # pipe :my_func
  defp get_pipe_func([func]) when is_atom(func) do
    build_function(quote(do: __MODULE__), func, [])
  end

  # pipeline MyPipeline
  defp get_pipe_func(module) when is_atom(module) do
    quote do: fn n -> unquote(module).pipe_through(n) end
  end

  # pipe :my_func, [arg_list]
  defp get_pipe_func([func, args]) when is_atom(func) and is_list(args) do
    build_function(quote(do: __MODULE__), func, args)
  end

  # pipe MyModule, :my_func
  defp get_pipe_func([module, func]) when is_atom(module) and is_atom(func) do
    build_function(module, func, [])
  end

  # pipe MyModule, :my_func, [arg_list]
  defp get_pipe_func([module, func, args]) when is_atom(module) and is_atom(func) and is_list(args) do
    build_function(module, func, args)
  end

  defp build_function(module, func_name, args) do
    quote do
      fn (input) ->
        try do
          apply(unquote(module), unquote(func_name), [input | unquote(args)])
        rescue
           e -> {:error, e.message}
        end
      end
    end
  end

end
