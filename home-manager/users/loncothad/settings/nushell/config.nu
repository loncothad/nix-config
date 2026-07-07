$env.config = {
  show_banner: false,

  edit_mode: vi

  buffer_editor: "hx"

  completions: {
    case_sensitive: false
    quick: true
    partial: true
    algorithm: "fuzzy"
  }

  cursor_shape: {
    vi_insert: line
    vi_normal: block
  }

  ls: {
    use_ls_colors: true
    clickable_links: true
  }

  table: {
    mode: rounded
    index_mode: always
  }
}