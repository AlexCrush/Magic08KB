Контроллер клавиатуры для Magic 08

# Фичи

* NoWait, в том числе в 7МГц турбо режиме
* Эмуляция чтения из порта FE
* Эмуляция чтения из порта 1F (Kempston-joystick)
* Эмуляция записи в порт TRDOS FF для смены дисковода A<->B с клавиатуры
* Индикация режима работы на LCD дисплее типа 1602 

# Железо

* Схема: https://easyeda.com/alexcrush/Magic081 , страница "Video&Sound"
* Микроконтроллер: ATMega 162, 20Mhz

# Компиляция

* Ассемблер: gavrasm: http://www.avr-asm-tutorial.net/gavrasm/index_en.html
* gavrasm main.asm  -e -a -s
* На выходе - main.hex, прошивка: avrdude -c usbasp -p m162 -U flash:w:main.hex:i   

