# XF_Reports
Этот плагин добавляет возможность напрямую репортить игрока на форум.
Команда ``!sm_report```

## Требования
[SteamWorks](https://users.alliedmods.net/~kyles/builds/SteamWorks/)

CSS/CS:GO, под TF2 не проверялось

## Установка
Создайте API-ключ в ACP вашего форума (admin.php?api-keys/) с нужными правами:
```
thread:read
thread:write
```

В конфиге файла (XF_Reports.cfg) измените под себя нужные данные:
```
"XF_Reports"
{
	"Settings"
	{
		"forum"			"" (Домен вашего форума. Пример: xenforo.com)
		"forum_id"	"" (Пример: hlmod.ru/forums/xosting.84/, где 84 - id форума)
		"apikey"		"" (Ваш апи ключ)
	}
}
```

## Баг-репорт
Если вы вдруг заметили баг в плагине, пожалуйста, создайте баг-репорт тут: 
[Issues](https://github.com/inzanty/XF_Reports/issues)

## Лицензия
[MIT](https://choosealicense.com/licenses/mit/)
