import gleam/dict.{type Dict}
import gleam/dynamic.{type DecodeError, type Dynamic}
import gleam/io
import gleam/list
import gleam/result

//Elixir.Module to pick the language and Module
//second string parameter is the function name in elixir
@external(erlang, "Elixir.Decode", "decode")
pub fn decode(item: String) -> a

pub fn main() {
  let object =
    decode(
      "{
  \"Name\": \"James\",
   \"Stats\": { \"Atk\":25,
                       \"Def\":\"Strong\"
                       },
\"Advanced_Skills\":[\"Rock Throw\",\"Tiger Claw\",\"Budda Wisdom\"]
   
   }",
    )

  io.debug(object)
  let character = deserialize_character(object)
  io.debug(character)
}

pub type Stats {
  Atk(Int)
  Def(String)
}

pub type Character {
  Character(
    name: String,
    stats_list: List(Stats),
    advanced_skills: List(String),
  )
}

pub type Field(a) {

  Root(item: Dict(String, Dict(String, Field(a))))
  ComplexField(item: Dict(String, Field(a)))
  Field(a)
}

pub fn of_int(x: Result(Field(a), Nil)) -> Int {
  case x {
    Ok(Field(a)) ->
      case dynamic.int(dynamic.from(a)) {
        Ok(x) -> x
        Error(_) -> 0
      }
    _ -> 0
  }
}

pub fn of_string(x: Result(Field(a), Nil)) -> String {
  case x {
    Ok(Field(a)) ->
      case dynamic.string(dynamic.from(a)) {
        Ok(x) -> x
        Error(_) -> ""
      }
    _ -> ""
  }
}

pub fn of_list(
  x: Result(Field(a), Nil),
  transformer: fn(Dynamic) -> Result(b, List(DecodeError)),
) -> List(b) {
  case x {
    Ok(Field(b)) -> {
      case dynamic.from(b) |> dynamic.list(of: transformer) {
        Ok(c) -> c
        _ -> list.new()
      }
    }
    _ -> list.new()
  }
}

pub fn deserialize_character(
  object: Dict(String, Dict(String, Field(a))),
) -> Character {
  let root = Root(object)

  let stats_list = [
    Atk(get_inner_field(root, ["Stats", "Atk"]) |> of_int),
    Def(get_inner_field(root, ["Stats", "Def"]) |> of_string),
  ]
  let advanced_skills =
    get_field(object, "Advanced_Skills") |> of_list(dynamic.string)
  let name = get_field(object, "Name") |> of_string
  Character(name, stats_list, advanced_skills)
}

pub fn get_field(a, field: String) -> Result(Field(a), Nil) {
  case dict.get(a, field) {
    Ok(x) -> Ok(Field(x))
    Error(_) -> Error(Nil)
  }
}

pub fn get_inner_field(
  object: Field(a),
  field_path: List(String),
) -> Result(Field(a), Nil) {
  // this case statement acts as the return
  //pop the first value off of the list of fields
  case list.pop(field_path, fn(_) { True }) {
    //if there is a head and tail dig into the structure recursively
    Ok(#(field, fields)) ->
      case object {
        Root(item) -> {
          //if we are at the root, go deeper
          case dict.get(item, field) {
            Ok(inner) -> get_inner_field(ComplexField(inner), fields)
            _ -> Error(Nil)
          }
        }
        ComplexField(item) -> {
          //if we have no more items left to pop, return the value found, otherwise keep going deeper
          case list.length(fields) {
            0 -> {
              dict.get(item, field)
            }
            _ -> {
              case dict.get(item, field) {
                Ok(inner) -> get_inner_field(inner, fields)

                _ -> Error(Nil)
              }
            }
          }
        }
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}
/// alll of these nil is just if your value didnt exist
