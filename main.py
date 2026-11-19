import asyncio 
import time
from typing import cast # use this to literally cast what it's supposed to expect.

from plyer import notification as _notification
from plyer.facades import Notification

# plyer's lazy Proxy confuses type checkers; tell Pylance the real type.
notification = cast(Notification, _notification)

default_timer = 25
default_rest  = 5
yes_list = ["yes", "y"]


def notify(title="ALERT", message="Time for a break"):
    notification.notify(
        title=title,
        message=message,
        timeout=10
    )

async def countdown(minutes, label="Work"):
    total = minutes * 60
    for remaining in range(total, 0, -1):
        mins, secs = divmod(remaining, 60)
        print(f"\r{label}: {mins:02d}:{secs:02d}", end="", flush=True)
        await asyncio.sleep(1)
    print(f"\r{label}: 00:00  done!")

async def timer(sessions):
    await countdown(default_timer, "Work")
    notify("Pomodoro", "Time for a break")
    await countdown(default_rest, "Break")
    notify("Pomodoro", "Back to work")
    
async def main():
    while True:
        usr = input("How many sessions would you be doing?\t")
        usr = usr.strip()
        usr = int(usr)

        if usr > 10:
            print("too many sessions, are you sure?")
            check = input().lower().strip()

            if check in yes_list:
                await timer(usr)
            else:
                pass

        else:
            await timer(usr)


if __name__ == "__main__":
    asyncio.run(main())