-- Эта информация рассказывает другим игрокам о моде.
name = "Kara"
description = "A character  for Don't Starve Together."
author = "Haswell edition"
version = "1.4.4" -- Сохранять скины предметов и использовать изображения инструментов в руке; добавить обмен предметами в хвостовом слоте.

-- Это имя темы мода на форуме: часть ссылки после знака ? и до первого знака &.
forumthread = "/files/file/950-extended-sample-character/"

-- По этой версии игра определяет, устарел ли мод; укажите актуальную версию игры, с которой он совместим.
api_version = 1

-- Совместим с Don't Starve Together.
dst_compatible = true

-- Не совместим с Don't Starve.
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

-- Моды персонажей должны быть установлены у всех игроков.
all_clients_require_mod = true 

icon_atlas = "modicon.xml"
icon = "modicon.tex"

-- Теги мода, отображаемые в списке серверов.
server_filter_tags = {
"character",
}

--configuration_options = {}
